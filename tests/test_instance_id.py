"""Run with python3 -m unittest discover -s tests -v (Bash, OpenSSL and Helm required)."""

from concurrent.futures import ThreadPoolExecutor
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import threading
import unittest
import uuid

ROOT = Path(__file__).resolve().parents[1]
COMPOSE = ROOT / "deploy/docker-compose"
CHART = ROOT / "deploy/kubernetes/charts/greptile"


def run(*args, **kwargs):
    return subprocess.run(args, capture_output=True, text=True, **kwargs)


class ComposeIdentity(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name)
        shutil.copytree(COMPOSE / "bin", self.root / "bin")
        shutil.copy(COMPOSE / ".env.example", self.root / ".env.example")
        shutil.copy(COMPOSE / "Caddyfile.example", self.root / "Caddyfile.example")
        self.file = self.root / ".env.greptile-instance"

    def generate(self):
        return run("bash", str(self.root / "bin/generate-instance-id.sh"))

    def test_first_setup_and_existing_install_upgrade(self):
        for script in ("setup-env.sh", "generate-instance-id.sh"):
            result = run("bash", str(self.root / "bin" / script))
            self.assertEqual(result.returncode, 0, result.stderr)
            value = self.file.read_text()
            self.assertEqual(uuid.UUID(value.strip().split("=", 1)[1]).version, 4)
        self.assertEqual(self.file.read_text(), value)

    def test_existing_identity_is_reused(self):
        value = f"GREPTILE_INSTANCE_ID={uuid.uuid4()}\n"
        self.file.write_text(value)
        self.assertEqual(self.generate().returncode, 0)
        self.assertEqual(self.generate().returncode, 0)
        self.assertEqual(self.file.read_text(), value)

    def test_concurrent_generators_keep_one_complete_identity(self):
        with ThreadPoolExecutor(max_workers=8) as pool:
            results = list(pool.map(lambda _: self.generate(), range(16)))
        for result in results:
            self.assertEqual(result.returncode, 0, result.stderr)
        value = self.file.read_text()
        self.assertEqual(len(value.splitlines()), 1)
        self.assertEqual(uuid.UUID(value.strip().split("=", 1)[1]).version, 4)
        self.assertEqual(self.generate().returncode, 0)
        self.assertEqual(self.file.read_text(), value)

    def test_invalid_identity_is_preserved_and_rejected(self):
        for value in ("", "GREPTILE_INSTANCE_ID=broken\n", "GREPTILE_INSTANCE_ID=broken\nOTHER=value\n"):
            self.file.write_text(value)
            self.assertNotEqual(self.generate().returncode, 0)
            self.assertEqual(self.file.read_text(), value)

    def test_restart_backfills_identity_and_detects_it_as_a_change(self):
        (self.root / ".env").write_text("AUTH_SAML_ONLY=false\n")
        # Avoid secret generation and Docker operations; exercise the real restart control flow.
        (self.root / "bin/generate-secrets.sh").write_text("#!/bin/bash\nexit 0\n")
        mock_bin = self.root / "mock-bin"
        mock_bin.mkdir()
        docker_log = self.root / "docker.log"
        docker = mock_bin / "docker"
        docker.write_text(f'#!/bin/bash\necho "$*" >> "{docker_log}"\n[[ "$1" != container ]]\n')
        docker.chmod(0o755)
        env = {**os.environ, "PATH": f"{mock_bin}:{os.environ['PATH']}"}
        restart = str(self.root / "bin/restart-greptile.sh")
        first = run("bash", restart, env=env)
        self.assertEqual(first.returncode, 0, first.stderr)
        identity = self.file.read_text()
        docker_log.write_text("")
        second = run("bash", restart, env=env)
        self.assertEqual(second.returncode, 0, second.stderr)
        self.assertNotIn("compose", docker_log.read_text())
        # Simulate an upgrade whose stored checksum does not include the new identity file.
        checksum = run("bash", "-c", "checksum=$(md5sum .env | cut -d' ' -f1); echo \"$checksum\" | md5sum | cut -d' ' -f1", cwd=self.root)
        (self.root / ".env.checksums").write_text(checksum.stdout)
        third = run("bash", restart, env=env)
        self.assertEqual(third.returncode, 0, third.stderr)
        self.assertIn("compose", docker_log.read_text())
        self.assertEqual(self.file.read_text(), identity)


class ClusterState(BaseHTTPRequestHandler):
    identity = None
    forbidden = False

    def log_message(self, *_):
        pass

    def do_GET(self):
        status = 200
        if self.path.split("?")[0] == "/version":
            body = {"major": "1", "minor": "35", "gitVersion": "v1.35.0", "gitCommit": "test", "gitTreeState": "clean", "buildDate": "2026-01-01T00:00:00Z", "goVersion": "go1.25.0", "compiler": "gc", "platform": "linux/amd64"}
        elif self.path.split("?")[0] == "/api":
            body = {"kind": "APIVersions", "apiVersion": "v1", "versions": ["v1"], "serverAddressByClientCIDRs": []}
        elif self.path.split("?")[0] == "/apis":
            body = {"kind": "APIGroupList", "apiVersion": "v1", "groups": [
                {"name": group, "versions": [{"groupVersion": version, "version": version.split("/")[1]}], "preferredVersion": {"groupVersion": version, "version": version.split("/")[1]}}
                for group, version in [("apps", "apps/v1"), ("batch", "batch/v1"), ("networking.k8s.io", "networking.k8s.io/v1"), ("policy", "policy/v1"), ("external-secrets.io", "external-secrets.io/v1")]
            ]}
        elif self.path.split("?")[0] in ["/api/v1", "/apis/apps/v1", "/apis/batch/v1", "/apis/networking.k8s.io/v1", "/apis/policy/v1", "/apis/external-secrets.io/v1"]:
            version = self.path.split("?")[0].split("/", 2)[2]
            resources = {
                "v1": [("configmaps", "ConfigMap"), ("secrets", "Secret"), ("services", "Service"), ("serviceaccounts", "ServiceAccount"), ("persistentvolumeclaims", "PersistentVolumeClaim"), ("pods", "Pod")],
                "apps/v1": [("deployments", "Deployment"), ("statefulsets", "StatefulSet")],
                "batch/v1": [("jobs", "Job")],
                "networking.k8s.io/v1": [("ingresses", "Ingress"), ("networkpolicies", "NetworkPolicy")],
                "policy/v1": [("poddisruptionbudgets", "PodDisruptionBudget")],
                "external-secrets.io/v1": [("externalsecrets", "ExternalSecret")],
            }[version]
            body = {"kind": "APIResourceList", "groupVersion": version, "resources": [
                {"name": name, "singularName": "", "namespaced": True, "kind": kind, "verbs": ["get", "list"]}
                for name, kind in resources
            ]}
        elif self.path.split("?")[0].endswith("/configmaps/greptile-instance-identity") and self.forbidden:
            status, body = 403, {"kind": "Status", "apiVersion": "v1", "status": "Failure", "reason": "Forbidden", "message": "test denies configmap access", "code": 403}
        elif self.path.split("?")[0].endswith("/configmaps/greptile-instance-identity") and self.identity is not None:
            body = {"kind": "ConfigMap", "apiVersion": "v1", "metadata": {"name": "greptile-instance-identity", "namespace": "identity-test", "labels": {"app.kubernetes.io/managed-by": "Helm"}, "annotations": {"meta.helm.sh/release-name": "greptile", "meta.helm.sh/release-namespace": "identity-test"}}, "data": {"GREPTILE_INSTANCE_ID": self.identity}}
        else:
            status, body = 404, {"kind": "Status", "apiVersion": "v1", "status": "Failure", "reason": "NotFound", "code": 404}
        payload = json.dumps(body).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(payload)))
        self.end_headers()
        self.wfile.write(payload)


class HelmIdentity(unittest.TestCase):
    def setUp(self):
        ClusterState.identity = None
        ClusterState.forbidden = False
        self.server = ThreadingHTTPServer(("127.0.0.1", 0), ClusterState)
        threading.Thread(target=self.server.serve_forever, daemon=True).start()
        self.addCleanup(self.server.server_close)
        self.addCleanup(self.server.shutdown)
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.kubeconfig = Path(self.directory.name) / "config"
        self.kubeconfig.write_text(json.dumps({"apiVersion": "v1", "kind": "Config", "current-context": "test", "clusters": [{"name": "test", "cluster": {"server": f"http://127.0.0.1:{self.server.server_port}"}}], "contexts": [{"name": "test", "context": {"cluster": "test", "user": "test"}}], "users": [{"name": "test", "user": {}}]}))
        self.kubeconfig.chmod(0o600)

    def render(self, *args):
        return run("helm", "template", "greptile", str(CHART), "--namespace", "identity-test", "--dry-run=server", "--disable-openapi-validation", "--kubeconfig", str(self.kubeconfig), *args)

    def identity(self, result):
        self.assertEqual(result.returncode, 0, result.stderr)
        match = re.search(r'^  GREPTILE_INSTANCE_ID: "([^"]+)"$', result.stdout, re.MULTILINE)
        self.assertIsNotNone(match)
        return match.group(1)

    def test_fresh_install_and_upgrade_without_previous_identity(self):
        for flags in ((), ("--is-upgrade",)):
            result = self.render(*flags)
            self.assertEqual(uuid.UUID(self.identity(result)).version, 4)
            self.assertIn("immutable: true", result.stdout)
            self.assertIn("helm.sh/resource-policy: keep", result.stdout)
            self.assertIn("name: greptile-instance-identity\n                  key: GREPTILE_INSTANCE_ID", result.stdout)

    def test_upgrade_preserves_existing_identity_and_external_secret_mode(self):
        ClusterState.identity = str(uuid.uuid4())
        required = ["DB_PASSWORD", "DIRECT_URL", "CSRF_SECRET", "HYDRA_SYSTEM_SECRET", "HYDRA_WEB_CLIENT_SECRET", "HYDRA_TOKEN_HOOK_SECRET", "ANTHROPIC_API_KEY", "OPENAI_API_KEY", "AZURE_OPENAI_API_KEY", "AWS_ACCESS_KEY_ID", "AWS_SECRET_ACCESS_KEY", "LITELLM_MASTER_KEY", "LLM_PROXY_KEY"]
        for mode in ("native", "external"):
            values = Path(self.directory.name) / "values.json"
            values.write_text(json.dumps({"secrets": {"mode": mode, "external": {"data": [{"secretKey": key, "remoteRef": {"key": f"test/{key}"}} for key in required]}}}))
            result = self.render("--is-upgrade", "-f", str(values))
            self.assertEqual(self.identity(result), ClusterState.identity)

    def test_invalid_existing_identity_blocks_rotation(self):
        ClusterState.identity = "broken"
        result = self.render("--is-upgrade")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("restore its original UUID", result.stderr)

    def test_permission_failure_does_not_silently_generate_a_replacement(self):
        ClusterState.forbidden = True
        result = self.render("--is-upgrade")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("test denies configmap access", result.stderr)


if __name__ == "__main__":
    unittest.main()

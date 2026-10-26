#!/usr/bin/env python3
"""Protect database credentials at the Helm-to-libpq configuration boundary.

Run after `helm dependency build deploy/kubernetes/charts/greptile` with
PyYAML and psycopg[binary] installed. No database or Kubernetes connection occurs.
"""

import os
from pathlib import Path
import subprocess
import unittest
from urllib.parse import quote

from psycopg.conninfo import conninfo_to_dict
import yaml


CHART = Path(__file__).resolve().parents[2] / "charts" / "greptile"
HELM = os.environ.get("HELM", "helm")


# --- Test fixture helpers ---------------------------------------------------
def render(values):
    """Exercise the real templates so the test also covers each URL consumer."""
    try:
        completed = subprocess.run(
            [HELM, "template", "greptile", str(CHART), "-f", "-"],
            input=yaml.safe_dump(values), text=True, capture_output=True, check=True,
        )
    except subprocess.CalledProcessError as error:
        raise AssertionError(
            f"Helm rendering failed (exit {error.returncode}):\n{error.stderr}"
        ) from error
    documents = []
    for document in yaml.safe_load_all(completed.stdout):
        if document:
            documents.append(document)
    return documents


def expected_url(user, password, host, database):
    return "postgresql://{}:{}@{}:5432/{}".format(
        quote(user, safe=""), quote(password, safe=""), host, quote(database, safe=""),
    )
# --- End test fixture helpers ----------------------------------------------


class DatabaseUrlTests(unittest.TestCase):
    def test_render_failure_includes_helm_diagnostic(self):
        """Keep Helm validation failures actionable from the test report alone."""
        with self.assertRaisesRegex(AssertionError, "network.authUrl requires https"):
            render({"network": {"authUrl": "http://auth.example.test"}})

    def test_default_urls_remain_unchanged(self):
        documents = render({})
        secret = next(item for item in documents if item["kind"] == "Secret" and item["metadata"]["name"] == "greptile-secrets")
        data = secret["stringData"]
        self.assertEqual(data["DIRECT_URL"], "postgresql://postgres:postgres@greptile-postgres:5432/postgres")
        self.assertEqual(data["DATABASE_URL"], "postgresql://postgres:postgres@greptile-pgbouncer:5432/postgres")
        self.assertEqual(data["VECTOR_DB_URL"], "postgresql://postgres:postgres@greptile-postgres:5432/vector")

    def test_database_components_round_trip_through_libpq(self):
        """A valid configured value must reach libpq without changing its meaning."""
        cases = {
            "ordinary": "plain_value-123",
            "slash": "before/after",
            "at": "before@after",
            "colon": "before:after",
            "hash": "before#after",
            "percent": "before%after",
            "literal_escape": "before%2Fafter",
            "plus": "before+after",
            "space": "before after",
            "query": "before?after",
            "unicode": "café-雪",
            "combined": "a@b:c/d?e#f%g+h i-雪",
        }
        for case, value in cases.items():
            for internal in (True, False):
                for pooled in (True, False):
                    with self.subTest(case=case, internal=internal, pooled=pooled):
                        self.check_render(value, internal, pooled)

    def check_render(self, value, internal, pooled):
        user, password = f"user-{value}", f"pass-{value}"
        database, vector = f"db-{value}", f"vector-{value}"
        values = {
            "postgres": {
                "enabled": internal,
                "auth": {"username": user, "postgresPassword": password, "database": database},
            },
            "externalDatabase": {
                "host": "database.example.test", "port": 5432, "user": user,
                "password": password, "database": database, "vectorDatabase": vector,
            },
            "pgbouncer": {"enabled": pooled},
        }
        documents = render(values)
        secret = next(item for item in documents if item["kind"] == "Secret" and item["metadata"]["name"] == "greptile-secrets")
        data = secret["stringData"]
        host = "greptile-postgres" if internal else "database.example.test"
        vector = "vector" if internal else vector
        for key, target_host, target_database in (
            ("DIRECT_URL", host, database),
            ("DB_URL", host, database),
            ("DATABASE_URL", "greptile-pgbouncer" if pooled else host, database),
            ("VECTOR_DB_URL", host, vector),
        ):
            actual = data[key]
            parsed = conninfo_to_dict(actual)
            self.assertEqual(
                {field: parsed[field] for field in ("user", "password", "host", "port", "dbname")},
                {"user": user, "password": password, "host": target_host, "port": "5432", "dbname": target_database},
                key,
            )
            self.assertEqual(actual, expected_url(user, password, target_host, target_database), key)
        # PgBouncer consumes DB_PASSWORD separately, outside a connection URI.
        self.assertEqual(data["DB_PASSWORD"], password)
        self.assertEqual(data["VECTOR_DB_PASSWORD"], password)
        migrations = []
        for item in documents:
            if item["kind"] == "Job":
                migrations.append(item)
        self.assertEqual(len(migrations), 2)
        for job in migrations:
            env = {entry["name"]: entry["value"] for entry in job["spec"]["template"]["spec"]["containers"][0]["env"]}
            self.assertEqual(env["DIRECT_URL"], data["DIRECT_URL"])
            self.assertEqual(env["DATABASE_URL"], data["DIRECT_URL"])


if __name__ == "__main__":
    unittest.main()

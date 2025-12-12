#!/usr/bin/env bash
set -euo pipefail
exec > >(tee /var/log/greptile-bootstrap.log | logger -t greptile-bootstrap) 2>&1
set -x

echo "[greptile-bootstrap] Updating base image packages"
dnf update -y >/dev/null

echo "[greptile-bootstrap] Installing Docker Engine + Compose plugin"
dnf install -y dnf-plugins-core awscli curl >/dev/null
if ! dnf repolist | grep -q "docker-ce-stable"; then
  dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo >/dev/null 2>&1
  if [[ -f /etc/yum.repos.d/docker-ce.repo ]]; then
    # Amazon Linux 2023 reports a releasever like 2023.9.20251110, which Docker does not publish.
    # Force every docker-ce repo stanza to reference the CentOS 9 path instead.
    sed -i 's|\$releasever|9|g' /etc/yum.repos.d/docker-ce.repo
  fi
fi
dnf remove -y docker docker-client docker-client-latest docker-common docker-latest docker-latest-logrotate docker-logrotate docker-engine >/dev/null 2>&1 || true
dnf install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin >/dev/null

systemctl enable --now docker
usermod -aG docker ec2-user || true

echo "[greptile-bootstrap] Preparing /opt/greptile"
install -d -m 0750 /opt/greptile
install -d -m 0750 /opt/greptile/bin
chown root:docker /opt/greptile
chown root:docker /opt/greptile/bin

cat <<'EOF_COMPOSE' | base64 -d | gzip -d > /opt/greptile/docker-compose.yml
${docker_compose_b64_gz}
EOF_COMPOSE
chmod 640 /opt/greptile/docker-compose.yml
chown root:docker /opt/greptile/docker-compose.yml

cat <<'EOF_ENV' | base64 -d | gzip -d > /opt/greptile/.env.example
${env_example_b64_gz}
EOF_ENV
chmod 640 /opt/greptile/.env.example
chown root:docker /opt/greptile/.env.example

cat <<'EOF_CADDY' | base64 -d | gzip -d > /opt/greptile/Caddyfile
${caddyfile_b64_gz}
EOF_CADDY
chmod 640 /opt/greptile/Caddyfile
chown root:docker /opt/greptile/Caddyfile

cat <<'EOF_LLMPROXY' | base64 -d | gzip -d > /opt/greptile/llmproxy-config.yaml
${llmproxy_config_b64_gz}
EOF_LLMPROXY
chmod 640 /opt/greptile/llmproxy-config.yaml
chown root:docker /opt/greptile/llmproxy-config.yaml

cat <<'EOF_PULL' | base64 -d | gzip -d > /opt/greptile/bin/pull-secrets.sh
${pull_secrets_b64}
EOF_PULL
chmod 750 /opt/greptile/bin/pull-secrets.sh
chown root:docker /opt/greptile/bin/pull-secrets.sh

cat <<'EOF_TOKEN' | base64 -d | gzip -d > /opt/greptile/bin/generate-hatchet-token.sh
${hatchet_token_script_b64}
EOF_TOKEN
chmod 750 /opt/greptile/bin/generate-hatchet-token.sh
chown root:docker /opt/greptile/bin/generate-hatchet-token.sh

cat <<'EOF_LOGIN' | base64 -d | gzip -d > /opt/greptile/bin/login-registry.sh
${login_registry_b64}
EOF_LOGIN
chmod 750 /opt/greptile/bin/login-registry.sh
chown root:docker /opt/greptile/bin/login-registry.sh

cat <<EOF_BOOTSTRAP > /opt/greptile/bootstrap.env
SECRETS_BUCKET="${secrets_bucket}"
SECRETS_OBJECT_KEY="${secrets_object_key}"
EOF_BOOTSTRAP
chmod 640 /opt/greptile/bootstrap.env
chown root:docker /opt/greptile/bootstrap.env

touch /opt/greptile/.env.hatchet-generated
chmod 640 /opt/greptile/.env.hatchet-generated
chown root:docker /opt/greptile/.env.hatchet-generated || true

cat <<'EOF_UNIT_IMAGES' | base64 -d | gzip -d > /etc/systemd/system/greptile-images.service
${systemd_images_b64}
EOF_UNIT_IMAGES
chmod 644 /etc/systemd/system/greptile-images.service

cat <<'EOF_UNIT_IMAGES_TIMER' | base64 -d | gzip -d > /etc/systemd/system/greptile-images.timer
${systemd_images_timer_b64}
EOF_UNIT_IMAGES_TIMER
chmod 644 /etc/systemd/system/greptile-images.timer

cat <<'EOF_UNIT_HATCHET' | base64 -d | gzip -d > /etc/systemd/system/greptile-hatchet.service
${systemd_hatchet_b64}
EOF_UNIT_HATCHET
chmod 644 /etc/systemd/system/greptile-hatchet.service

cat <<'EOF_UNIT_HATCHET_TOKEN' | base64 -d | gzip -d > /etc/systemd/system/greptile-hatchet-token.service
${systemd_hatchet_token_b64}
EOF_UNIT_HATCHET_TOKEN
chmod 644 /etc/systemd/system/greptile-hatchet-token.service

cat <<'EOF_UNIT_APP' | base64 -d | gzip -d > /etc/systemd/system/greptile-app.service
${systemd_app_b64}
EOF_UNIT_APP
chmod 644 /etc/systemd/system/greptile-app.service

cat <<'EOF_UNIT_SAML' | base64 -d | gzip -d > /etc/systemd/system/greptile-saml.service
${systemd_saml_b64}
EOF_UNIT_SAML
chmod 644 /etc/systemd/system/greptile-saml.service

/opt/greptile/bin/pull-secrets.sh || true

systemctl daemon-reload
systemctl enable --now greptile-images.timer || true
systemctl enable --now greptile-app.service || true
systemctl enable --now greptile-saml.service || true

echo "[greptile-bootstrap] Completed"

#!/usr/bin/env bash
set -euo pipefail
exec > >(tee /var/log/greptile-bootstrap.log | logger -t greptile-bootstrap) 2>&1
set -x

echo "[greptile-bootstrap] Updating base image packages"
dnf update -y >/dev/null

echo "[greptile-bootstrap] Installing Docker Engine + Compose plugin"
dnf install -y docker docker-compose-plugin awscli >/dev/null

systemctl enable --now docker
usermod -aG docker ec2-user || true

echo "[greptile-bootstrap] Preparing /opt/greptile"
install -d -m 0750 /opt/greptile
chown root:docker /opt/greptile

cat <<'EOF_COMPOSE' | base64 -d > /opt/greptile/docker-compose.yml
${docker_compose_b64}
EOF_COMPOSE
chmod 640 /opt/greptile/docker-compose.yml
chown root:docker /opt/greptile/docker-compose.yml

cat <<'EOF_ENV' | base64 -d > /opt/greptile/.env.example
${env_example_b64}
EOF_ENV
chmod 640 /opt/greptile/.env.example
chown root:docker /opt/greptile/.env.example

cat <<'EOF_PULL' | base64 -d > /opt/greptile/pull-secrets.sh
${pull_secrets_b64}
EOF_PULL
chmod 750 /opt/greptile/pull-secrets.sh
chown root:docker /opt/greptile/pull-secrets.sh

cat <<'EOF_UNIT' | base64 -d > /etc/systemd/system/greptile-compose.service
${systemd_unit_b64}
EOF_UNIT
chmod 644 /etc/systemd/system/greptile-compose.service

/opt/greptile/pull-secrets.sh || true

if [[ -f /opt/greptile/.env ]]; then
  echo "[greptile-bootstrap] Attempting initial docker compose pull"
  cd /opt/greptile && /usr/bin/docker compose pull || true
fi

systemctl daemon-reload
systemctl enable --now greptile-compose.service || true

echo "[greptile-bootstrap] Completed"

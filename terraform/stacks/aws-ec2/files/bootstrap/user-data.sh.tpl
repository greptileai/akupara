#!/usr/bin/env bash
set -euo pipefail
exec > >(tee /var/log/greptile-bootstrap.log | logger -t greptile-bootstrap) 2>&1
set -x

login_greptile_ecr() {
  local env_file="/opt/greptile/.env"
  local default_region="${aws_region}"

  if [[ ! -f "$env_file" ]]; then
    echo "[greptile-bootstrap] Skipping ECR login; $env_file not present yet"
    return 0
  fi

  local registry_line
  registry_line=$(grep -E '^CONTAINER_REGISTRY=' "$env_file" | tail -n1 || true)
  if [[ -z "$registry_line" ]]; then
    echo "[greptile-bootstrap] No CONTAINER_REGISTRY defined; skipping ECR login"
    return 0
  fi

  local registry_value
  registry_value="${registry_line#CONTAINER_REGISTRY=}"
  registry_value="${registry_value%$'\r'}"
  registry_value="${registry_value%\"}"
  registry_value="${registry_value#\"}"
  registry_value="${registry_value%\'}"
  registry_value="${registry_value#\'}"

  local registry_host="${registry_value%%/*}"
  if [[ -z "$registry_host" ]]; then
    echo "[greptile-bootstrap] Could not parse registry host from CONTAINER_REGISTRY=$registry_value"
    return 0
  fi

  if [[ $registry_host != *.dkr.ecr.*.amazonaws.com ]]; then
    echo "[greptile-bootstrap] Registry $registry_host is not an AWS ECR endpoint; skipping ECR login"
    return 0
  fi

  local registry_region="${registry_host#*.dkr.ecr.}"
  registry_region="${registry_region%.amazonaws.com}"
  if [[ -z "$registry_region" || "$registry_region" == "$registry_host" ]]; then
    registry_region="$default_region"
  fi

  echo "[greptile-bootstrap] Logging into ECR registry $registry_host (region $registry_region)"
  if aws ecr get-login-password --region "$registry_region" | docker login --username AWS --password-stdin "$registry_host"; then
    echo "[greptile-bootstrap] ECR login succeeded"
  else
    echo "[greptile-bootstrap] WARNING: ECR login failed; Greptile images may not pull" >&2
  fi
}

echo "[greptile-bootstrap] Updating base image packages"
dnf update -y >/dev/null

echo "[greptile-bootstrap] Installing Docker Engine + Compose plugin"
dnf install -y dnf-plugins-core awscli >/dev/null
if ! dnf repolist | grep -q "docker-ce-stable"; then
  dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo >/dev/null 2>&1
fi
dnf remove -y docker docker-client docker-client-latest docker-common docker-latest docker-latest-logrotate docker-logrotate docker-engine >/dev/null 2>&1 || true
dnf install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin >/dev/null

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

cat <<EOF_BOOTSTRAP > /opt/greptile/bootstrap.env
SECRETS_BUCKET="${secrets_bucket}"
SECRETS_OBJECT_KEY="${secrets_object_key}"
EOF_BOOTSTRAP
chmod 640 /opt/greptile/bootstrap.env
chown root:docker /opt/greptile/bootstrap.env

cat <<'EOF_UNIT' | base64 -d > /etc/systemd/system/greptile-compose.service
${systemd_unit_b64}
EOF_UNIT
chmod 644 /etc/systemd/system/greptile-compose.service

/opt/greptile/pull-secrets.sh || true
login_greptile_ecr || true

if [[ -f /opt/greptile/.env ]]; then
  echo "[greptile-bootstrap] Attempting initial docker compose pull"
  cd /opt/greptile && /usr/bin/docker compose pull || true
fi

systemctl daemon-reload
systemctl enable --now greptile-compose.service || true

echo "[greptile-bootstrap] Completed"

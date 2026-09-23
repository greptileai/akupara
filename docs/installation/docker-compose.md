# Install with Docker Compose

Single-node setup for smaller teams. Confirm [requirements](./requirements.md) first.

All commands below run from `deploy/docker-compose/` unless noted.

## 1. Clone the repository

Copy this repository onto your Linux server and change into the Docker Compose directory:

```bash
cd deploy/docker-compose
```

## 2. Create environment files

```bash
./bin/setup-env.sh
```

This creates:

- `.env` from `.env.example` (if it does not already exist)
- `Caddyfile` from `Caddyfile.example` (if it does not already exist)

## 3. Start Hatchet

Hatchet is the internal task queue Greptile uses.

1. Start Hatchet:

   ```bash
   ./bin/start-hatchet.sh
   ```

2. Generate the Hatchet authentication token:

   ```bash
   ./bin/generate-hatchet-token.sh
   ```

3. Open the Hatchet admin portal at `http://<your_server_ip>:8080`.

4. Log in with the default credentials:

   - **Username:** `admin@example.com`
   - **Password:** `Admin123!!`

5. Go to **Settings > General > Members** and change the default admin password.

## 4. Authenticate with the container registry

Set the registry in `.env`:

```bash
# Set to 'ecr' or 'dockerhub'
REGISTRY_PROVIDER=dockerhub
CONTAINER_REGISTRY=<your_registry_url_from_greptile>
```

Then run:

```bash
./bin/login-registry.sh
```

### Manual authentication

**Docker Hub:**

```bash
echo "<TOKEN>" | docker login --username <DOCKERHUB_USERNAME> --password-stdin
```

**AWS ECR:**

1. Share your AWS account ID with the Greptile team.
2. Log in:

   ```bash
   aws ecr get-login-password --region us-east-1 \
   | docker login --username AWS --password-stdin <greptile_ecr_registry>
   ```

## 5. Configure environment variables

Open `.env` and search for every line containing `TODO:`. Those values must be set before starting Greptile.

Also configure:

- [Networking](../configuration/networking.md) (`IP_ADDRESS`, `APP_URL`)
- [GitHub App creation](../configuration/github_app_creation.md) if you use GitHub or GitHub Enterprise
- [LLM providers](../configuration/llm-providers.md)

If you use a self-managed Postgres instance, update every environment variable starting with `DB_`.

Optional static feature flags go in `FEATURE_FLAGS_JSON` as a JSON object with boolean values. Leave it as `'{}'` unless Greptile asks you to enable a flag.

Optional observability can be enabled by setting `O11Y_ENABLED='true'` and `GRAFANA_URL`. See [Observability](../operations/observability.md).

## 6. Start Greptile

```bash
./bin/start-greptile.sh
```

## 7. Verify services

```bash
docker compose ps
```

You should see:

**Hatchet**

- `hatchet-postgres`
- `hatchet-rabbitmq`
- `hatchet-migration`
- `hatchet-setup-config`
- `hatchet-engine`
- `hatchet-api`
- `hatchet-frontend`
- `hatchet-caddy`

**Greptile**

- `greptile-postgres`
- `greptile-redis`
- `greptile-db-migration`
- `greptile-web`
- `greptile-auth`
- `greptile-api`
- `greptile-indexer-chunker`
- `greptile-webhook`
- `greptile-worker`
- `greptile-jobs`
- `greptile-llmproxy`

## Scripts

| Script | Purpose |
|--------|---------|
| `bin/start-hatchet.sh` | Start Hatchet task queue services |
| `bin/start-greptile.sh` | Start Greptile application services |
| `bin/login-registry.sh` | Authenticate with the container registry |
| `bin/generate-hatchet-token.sh` | Generate the Hatchet authentication token |
| `bin/generate-secrets.sh` | Generate `JWT_SECRET`, `TOKEN_ENCRYPTION_KEY`, `LITELLM_MASTER_KEY`, `WEB_TRIGGER_SECRET` |
| `bin/setup-env.sh` | Create `.env` and `Caddyfile` from example templates |
| `bin/wait-for-service.sh` | Wait for a Docker Compose service to become healthy |

Check whether generated secrets are already set:

```bash
./bin/generate-secrets.sh --check-only
```

Wait for a specific service:

```bash
./bin/wait-for-service.sh greptile-postgres 60 --profile greptile
```

## Next steps

- Configure and expose the right services: [Networking](../configuration/networking.md)
- If using GitHub, you need to create a GitHub App in your GitHub instance: [GitHub App creation](../configuration/github_app_creation.md)
- (Optional) Set up SSO for your organization: [SSO](../configuration/sso.md)

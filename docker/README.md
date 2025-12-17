## Setting up Greptile using Docker Compose

The easiest way to deploy Greptile is on a single VM using Docker Compose. This approach is ideal for teams with ≤100 members. For larger teams or higher scalability requirements, we recommend checking out the [Kubernetes deployment](/greptile-helm/README.md).

### Requirements

#### Hardware & Infrastructure
* One Linux server with the following specifications:
  * 32-64GB RAM
  * 8-16 CPUs
  * **Disk space requirements:**
    * **Minimum 30GB** for Docker images (~15GB) and system overhead
    * Additional space for repository checkouts during code reviews (varies by repo sizes)
    * Recommended: 50-100GB root volume for comfortable operation
  * (Optional) A managed Postgres database (stores metadata only, minimal storage needed)

#### Software
* Docker 23.x or newer
* Docker Compose v2.20.0 or newer

#### LLM Access
* Access to the following LLM models:
  * Latest Anthropic models or latest AWS Bedrock models
  * (Recommended but not required) Latest OpenAI models
  * Recommended rate limits: At least 100 requests per minute and 800,000 tokens per minute

#### Container Registry
* Access to Greptile's container images (shared with you by Greptile)

### Networking Requirements

#### Ports to Expose Externally
Only these ports should be exposed externally:
- `3000` - Greptile web application
- `3007` - Webhook receiver (GitHub/GitLab)
- `8080` - Hatchet admin UI (optional, restrict access)
- `5225` - SAML portal (only if using SSO)

#### Keep Internal Only
These ports should NOT be exposed externally:
- `5432` - PostgreSQL databases
- `5672/5673` - RabbitMQ AMQP
- `7077` - Hatchet gRPC
- `15672/15673` - RabbitMQ Management UI

## Quickstart

### 1. Clone the Repository
Clone or copy this repository (akupara) onto your Linux server and navigate to the docker directory:
```bash
cd docker
```

### 2. Start Hatchet
Hatchet is the internal task queue used by Greptile.

1. Run the Hatchet startup script:
   ```bash
   ./bin/start-hatchet.sh
   ```
   This will download the public images for Hatchet and start the services.

2. Generate the Hatchet authentication token:
   ```bash
   ./bin/generate-hatchet-token.sh
   ```
   This token allows Greptile services to communicate with Hatchet.

3. Once Hatchet has started, verify it's running by accessing the Hatchet admin portal at:
   ```
   http://<your_server_ip>:8080
   ```

4. Log in with the default credentials:
   - **Username:** `admin@example.com`
   - **Password:** `Admin123!!`

5. **Important:** Go to **Settings > General > Members** and change the default admin password.

### 3. Authenticate with Container Registry
Ensure you can pull Greptile's images by logging in to the appropriate container registry.

First, configure your registry provider in `.env`:
```bash
# Set to 'ecr' or 'dockerhub'
REGISTRY_PROVIDER=dockerhub
CONTAINER_REGISTRY=<your_registry_url_from_greptile>
```

Then run the registry login helper:
```bash
./bin/login-registry.sh
```

#### Manual Authentication (Alternative)

**Docker Hub:**
```bash
echo "<TOKEN>" | docker login --username <DOCKERHUB_USERNAME> --password-stdin
```

**AWS ECR:**
1. Share your AWS account ID with the Greptile team
2. Log in to AWS ECR:
   ```bash
   aws ecr get-login-password --region us-east-1 \
   | docker login --username AWS --password-stdin <greptile_ecr_registry>
   ```

### 4. Configure Environment Variables
Open the `.env` file, which contains all the environment variables to configure Greptile and Hatchet.

1. **Required:** Search for all lines containing `TODO:` - these environment variables must be updated before starting Greptile.

2. **If using AWS Bedrock:** Create an access key ID and secret access key under **AWS Bedrock > API Keys > Long-term API Keys** first.

3. **If using your own self-managed Postgres:**
   - Double-check all environment variables starting with `DB_` and update them accordingly.

4. **If using self-hosted GitHub:**
   - You will need to create a GitHub App on your instance and copy some values into the `.env` file.
   - For a detailed guide, see [GitHubApp.md](docs/GitHubApp.md).

### 5. Start Greptile Services
Once you have filled out the environment variables in `.env`, start the Greptile services:
```bash
./bin/start-greptile.sh
```

### 6. Verify Services
Check if all containers started successfully:
```bash
docker compose ps
```

You should see the following services running:

**Hatchet services:**
* hatchet-postgres
* hatchet-rabbitmq
* hatchet-migration
* hatchet-setup-config
* hatchet-engine
* hatchet-api
* hatchet-frontend
* hatchet-caddy

**Greptile services:**
* greptile-postgres
* greptile-db-migration
* greptile-web
* greptile-auth
* greptile-api
* greptile-indexer-chunker
* greptile-indexer-summarizer
* greptile-webhook
* greptile-reviews
* greptile-jobs
* greptile-llmproxy

## Further Configuration

### Custom Domains
To set up custom domains and DNS, please refer to the guide: [CustomDomains.md](docs/CustomDomains.md)

### Single Sign-On (SSO)
To set up SSO, please refer to the guide: [SSO.md](docs/SSO.md)

## Troubleshooting

Here is a checklist of steps to follow when troubleshooting Greptile:

### 1. Check Service Status
Verify that all services are running successfully:
```bash
docker compose ps
```

### 2. Inspect Service Logs
If a service is restarting periodically, check its logs:
```bash
docker compose logs <service_name>
```

Example:
```bash
docker compose logs greptile-web
```

Share any error messages with the Greptile support team.

### 3. Monitor Workflow Health
Open the Hatchet portal at `http://<your_server_ip>:8080` and check if certain workflows are failing at a higher rate (e.g., reviews workflow).

### 4. Debug LLM Issues
When debugging errors related to LLM calls, check the logs of the LLM proxy service that routes all LLM calls to the providers:
```bash
docker compose logs greptile-llmproxy
```

## Scripts

All scripts are located in the `bin/` directory:

| Script | Purpose |
|--------|---------|
| `bin/start-hatchet.sh` | Start Hatchet task queue services |
| `bin/start-greptile.sh` | Start Greptile application services |
| `bin/login-registry.sh` | Authenticate with container registry (ECR/Docker Hub) |
| `bin/generate-hatchet-token.sh` | Generate Hatchet authentication token |
| `bin/generate-secrets.sh` | Generate JWT_SECRET, TOKEN_ENCRYPTION_KEY, LLM_PROXY_KEY |
| `bin/setup-env.sh` | Create `.env` and `Caddyfile` from example templates |
| `bin/wait-for-service.sh` | Wait for a Docker Compose service to be healthy |

### Example Usage

Check if secrets are set:
```bash
./bin/generate-secrets.sh --check-only
```

Wait for a specific service:
```bash
./bin/wait-for-service.sh greptile-postgres 60 --profile greptile
```

## SystemD Installation (Optional)

For automatic startup on boot, you can install the provided SystemD service files.

### Prerequisites
- Copy the Greptile files to `/opt/greptile`
- Ensure `.env` is configured in `/opt/greptile/.env`

### Installation

1. Copy service files:
   ```bash
   sudo cp /opt/greptile/systemd/*.service /etc/systemd/system/
   sudo systemctl daemon-reload
   ```

2. Enable services for automatic startup:
   ```bash
   sudo systemctl enable greptile-images greptile-hatchet greptile-hatchet-token greptile-app
   ```

3. Start services:
   ```bash
   sudo systemctl start greptile-hatchet
   sudo systemctl start greptile-hatchet-token
   sudo systemctl start greptile-app
   ```

### Optional: Automatic Image Updates

To enable daily image pulls:
```bash
sudo cp /opt/greptile/systemd/greptile-images.timer /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now greptile-images.timer
```

### Service Management

Check service status:
```bash
sudo systemctl status greptile-hatchet
sudo systemctl status greptile-hatchet-token
sudo systemctl status greptile-app
```

View logs:
```bash
sudo journalctl -u greptile-hatchet
sudo journalctl -u greptile-hatchet-token
sudo journalctl -u greptile-app
```

Restart services:
```bash
sudo systemctl restart greptile-hatchet
sudo systemctl restart greptile-hatchet-token
sudo systemctl restart greptile-app
```

### SystemD Service Dependency Chain

```
greptile-images.service
    ↓
greptile-hatchet.service (starts Hatchet containers)
    ↓
greptile-hatchet-token.service (generates auth token)
    ↓
greptile-app.service (starts Greptile containers)
```

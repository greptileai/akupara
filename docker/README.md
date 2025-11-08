## Setting up Greptile using Docker Compose

The easiest way to deploy Greptile is on a single VM using Docker Compose. This approach is ideal for teams with ≤100 members. For larger teams or higher scalability requirements, we recommend checking out the [Kubernetes deployment](/greptile-helm/README.md).

### Requirements

#### Hardware & Infrastructure
* One Linux server (we recommend an EC2 instance on AWS) with the following specifications:
  * 16-32GB RAM
  * 4-8 CPUs
  * Disk space: 20GB + size of the repositories you want to use Greptile on
  * (Optional but recommended) A managed Postgres database (e.g., AWS RDS) with 20GB storage

#### Software
* Docker 23.x or newer
* Docker Compose v2.5.0 or newer

#### LLM Access
* Access to the following LLM models:
  * Latest Anthropic models or latest AWS Bedrock models
  * (Recommended but not required) Latest OpenAI models
  * Recommended rate limits: At least 100 requests per minute and 800,000 tokens per minute

#### Container Registry
* Access to Greptile's container images (shared with you by Greptile)

### Networking Requirements 
The following ports should be open to inbound traffic:
- `80` and `443` - Required for HTTP and HTTPS traffic
- `3000` - Default port to access the Greptile front-end
- `3007` - Default port Greptile listens on for GitHub/GitLab webhook events
- `8080` - Default port for the Hatchet front-end (useful for debugging and checking system health)
- `5225` - Default port for SAML/SSO portal (only required if using SSO)

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
   ./start_hatchet.sh
   ```
   This will download the public images for Hatchet.

2. Once Hatchet has started, verify it's running by accessing the Hatchet admin portal at:
   ```
   http://<your_server_ip>:8080
   ```

3. Log in with the default credentials:
   - **Username:** `admin@example.com`
   - **Password:** `Admin123!!`

4. **Important:** Go to **Settings > General > Members** and change the default admin password.

### 3. Authenticate with Container Registry
Ensure you can pull Greptile's images by logging in to the appropriate container registry:

**Option A: Docker Hub**
```bash
echo "<TOKEN>" | docker login --username <DOCKERHUB_USERNAME> --password-stdin
```

**Option B: AWS ECR**
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
./start_greptile.sh
```

### 6. Verify Services
Check if all containers started successfully:
```bash
docker compose ps
```

You should see the following services running:
* caddy
* greptile_api_service
* greptile_auth_service
* greptile_indexer_chunker
* greptile_indexer_summarizer
* greptile_jobs_service
* greptile_llmproxy_service
* greptile_reviews_service
* greptile_web_service
* greptile_webhook_service
* hatchet-api
* hatchet-engine
* hatchet-frontend
* postgres-hatchet
* rabbitmq
* greptile_postgres_db

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
docker compose logs greptile_web_service
```

Share any error messages with the Greptile support team.

### 3. Monitor Workflow Health
Open the Hatchet portal at `http://<your_server_ip>:8080` and check if certain workflows are failing at a higher rate (e.g., reviews workflow).

### 4. Debug LLM Issues
When debugging errors related to LLM calls, check the logs of the LLM proxy service that routes all LLM calls to the providers:
```bash
docker compose logs greptile_llmproxy_service
```

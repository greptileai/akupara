## Setting up Greptile using Docker Compose

The easiest way to deploy Greptile is on a single VM using docker compose. This approach is ideal for teams <=100. For bigger teams of higher scalability requirements, we recommend checking out the [Kubernetes deployment](/greptile-helm/README.md)

### Requirements
* One Linux server (we recommend an EC2 instance on AWS) with the following specs:
* 16-32GB RAM
* 4-8 CPUS
* Disk space (20GB + size of the repositories you want to use Greptile on)
* (optional but recommended) a maanged Postgres (i.e. AWS RDS) with 20GB
* Docker 23.x or newer
* Docker compose v2.5.0 or newer
* Access to following LLM models:
* latest Anthropic models or latest Bedrock models
* (Recommended but not required) latest OpenAI models
* We recommend at least 100 requests per minute and 800,000 tokens per minute.
* Access to Greptile's container iamges (shared to you by Greptile) 

### Networking requirements 
- The following ports should be open to inbound traffic
    - `80` and `443` - required for HTTP and HTTPS traffic
    - `3000` - this is the default port to access the greptile front-end
    - `3007` - this is the default port Greptile listens on for github/gitlab webhook events.
    - `8080` - this is the default port for the Hatchet front-end (useful for debugging and checking system health)
    - `5225` - this is the default port for SAML/SSO portal (only required if using SSO)

## Quickstart
1. Clone/Copy this repository (akupara) onto the Linux server
2. `cd` into `docker` directory
3. Prepare to start hatchet - The internal task queue userd by Greptile
    3.1 Run `./start_hatchet`: This should download the public images for Hatchet
    3.2 After hatchet has been started, open your browser and try to access the hatchet admin portal under `http://<your_server_ip>:8080`
    3.3 Log in with username:`admin@example.com` and password `Admin123!!`
    3.4 Go to Settings > General > Members and change the default password of the admin.
4. Ensure you can pull Greptile's image by logging in:
4.1 If using Docker Hub, obtain token from Greptile and then run : `echo "<TOKEN>" | docker login --username <DOCKERHUB_USERNAME> --password-stdin`
4.2 If using AWS ECR: Share your AWS ID with Greptile team. Then log in to your AWS acount via:
```
aws ecr get-login-password --region us-east-1 \
| docker login --username AWS --password-stdin <greptile_ecr_registry>
```
5. Open `.env` - this file contains all the environment variables to configure Greptile and hatchet. the following environment varibales have to be updated by you:
5.1. Search for all the lines containing `TODO: ` these env var have to be updated by you before starting Greptile
5.2. Note: If using AWS Bedrock, create a access key id and secret access key under AWS bedrock > API keys > long-term API keys first.
5.2. Note: If you plan to use your own self managed Postgres:
5.2.1 Double check all the env vars starting with `DB_` and update them accordingly
5.3. Note: If using Greptile with self-hosted GitHub, you will have to create a GitHub app on your instance and copy-paste some of the values into the `.env` file. For a detailed guide on how to do that, please check [GitHubApp.md](docs/GitHubApp.md)
6. Once you have filled out the env vars in `.env`, start the greptile services by running `./start_greptile.sh`.
7. Check if the containers all came up successfully vi `docker compose ps` you should see the following services:
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

## Further configuration
* To set up Custom Domains (and DNS) please check this guide: [CustomDomains.md](docs/CustomDomains.md)
* To set up SSO, please check this guide: [SSO.md](docs/SSO.md)

## Troubleshooting Checklist
Here is a checklist of things to do when troubleshooting Greptile
1. Check if all services are running successfully:
`docker compose ps`
2. If a service is restarting periodically, check the logs with `docker compose logs <service_name>` e.g. `docker compose logs greptile_web_service`. Share any 
3. Open the hatchet portal and check if certain workflows are failing at a higher rate, such as reviews workflow. 
4. When debugging errors observed with LLM calls, check the logs of the llmproxzy service that routes all LLM calls to the LLm providers: `docker compose logs greptile_llmproxy_service`

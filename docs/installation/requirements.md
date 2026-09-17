# Requirements

Self-hosted Greptile can run on a single Linux host with Docker Compose, or on a Kubernetes cluster. Review this page before you start either install.

## Hardware and infrastructure

### Docker Compose (single node)

One Linux server with:
- 64 GB RAM
- 32 CPUs
- 1 TB of root volume to store repository-related data

### Kubernetes

Kubernetes storage is configured separately. Bundled Postgres and the shared workdir PVC must have enough backing storage for your workload. Review `postgres.primary.persistence.size` and `storage.sharedWorkdir.size` before deploying to a small cluster. For CPU, memory, and worker replica counts, see [Scaling](../operations/scaling.md).

## Software

### Docker Compose

- Docker 23.x or newer
- Docker Compose v2.20.0 or newer

### Kubernetes

- A cluster that can run Helm 3 charts
- An ingress controller (Greptile creates Ingress resources but does not install a controller)
- A separate Hatchet deployment (`hatchet-stack-api` and `hatchet-stack-engine` must be reachable)
- Cluster policy that allows the review worker to run privileged with `SYS_ADMIN` and a `/sys/fs/cgroup` mount

## Container registry

You need access to Greptile's container images. Greptile shares registry credentials and image tags with you.

Supported registry providers:

- Docker Hub
- AWS ECR (share your AWS account ID with Greptile first)

## LLM access

Greptile requires access to LLM models for reviews and related workflows.

Recommended models:
- Anthropic:
  * Claude Sonnet 4.6 or better
  * Claude Haiku 4.5 or better
- OpenAI:
  * GPT: GPT 5.5 or better
  * Embeddings: text-embedding-3-small
- Recommended rate limits: at least 100 requests per minute and 800,000 tokens per minute

See [LLM providers](../configuration/llm-providers.md) for API keys, Bedrock, Azure, and GPT routing.


## Next steps

- [Install with Docker Compose](./docker-compose.md) for a single-node setup
- [Install with Kubernetes](./kubernetes.md) for a cluster setup

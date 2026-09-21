# Architecture overview

Self-hosted Greptile runs as independently scalable services. The stack depends on Hatchet for task orchestration and PostgreSQL for persistence.

![Current self-hosted Greptile architecture](../../architecture_diagram/Greptile_architecture.current.svg)

The tables below list the workloads this repository deploys. Kubernetes names assume a Helm release named `greptile`. Docker Compose names that differ are noted in parentheses.

## Application services

| Service | Description |
|---------|-------------|
| `web` | User-facing dashboard. Operators and developers sign in here and manage repositories, reviews, and settings. |
| `auth-v2` and `hydra` (`auth` in Compose) | Authentication service used by the dashboard; `hydra` is the OAuth/OIDC issuer. The Kubernetes chart runs legacy `auth` instead when `authV2.enabled: false`. |
| `api` | Application API used by the web UI and by CLI or API clients. Starts review and indexing workflows on Hatchet. |
| `webhook` | Receives GitHub and GitLab webhook events and dispatches review and repository-sync work to Hatchet. |
| `worker` | Executes review workflows: clones repositories, runs the review sandbox, posts comments to the SCM provider, and stores review state. Runs privileged with `SYS_ADMIN` so sandboxing can work. |
| `chunker` | Executes indexing workflows: fetches repositories, chunks and embeds code, and stores indexes and metadata. |
| `jobs` | Schedules recurring analytical tasks. |
| `llmproxy` | Internal [LiteLLM](https://docs.litellm.ai/) proxy. Worker and chunker send model and embedding requests here; the proxy routes them to the configured LLM providers. |

## Optional services

| Service | Description |
|---------|-------------|
| `jackson` (`saml-jackson` in Compose) | [BoxyHQ Jackson](https://boxyhq.com/docs/jackson/overview) SAML identity service. Deployed only when SSO is enabled. See [SSO](../configuration/sso.md). |

## Data and platform

| Service | Description |
|---------|-------------|
| `postgres` | PostgreSQL with pgvector. Stores application metadata, indexes, and review state. Can be bundled or replaced with a managed database. |
| `redis` | Valkey (Redis-compatible) store required by the application services. Bundled by default; point at an existing instance with `redis.external.host` on Kubernetes or `REDIS_HOST` in Compose. |
| `pgbouncer` | Connection pooler in front of Postgres. Deployed by the Kubernetes chart when enabled; not used in Docker Compose. |
| `db-migration` | One-shot job that applies database schema migrations before application services start. |
| Hatchet | Task queue used for review, indexing, and recurring jobs. Installed separately on Kubernetes (`hatchet-stack`). Docker Compose starts Hatchet and its Postgres and RabbitMQ dependencies alongside Greptile. |

Hatchet UI should show registered workers for `chunker` and `worker` after a successful deploy.

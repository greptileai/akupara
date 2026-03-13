# Greptile Helm Chart (v2)

This chart deploys Greptile application workloads on Kubernetes with parity to the `deploy/docker-compose/` stack.

## Scope
- Included: `web`, `auth`, `api`, `chunker`, `summarizer`, `worker`, `webhook`, `jobs`, `llmproxy`, optional `jackson`, DB migration job.
- Excluded: Hatchet deployment itself (deploy separately).

## Quick Start
1. Install Hatchet separately (see `../profiles/hatchet-values.yaml`).
2. Copy `../profiles/values.user.example.yaml` to `../profiles/values.user.yaml` and fill required values.
3. Create secrets in `values` (`secrets.mode=native`) or via External Secrets (`secrets.mode=external`).
4. Install:
   ```bash
   helm dependency update ./charts/greptile
   helm upgrade --install greptile ./charts/greptile -f ./charts/profiles/values.user.yaml
   ```

## Required Inputs
- `global.registry`, `global.tag`
- Hatchet endpoints and token (`hatchet.*`, `HATCHET_CLIENT_TOKEN`)
- Greptile auth/encryption/LLM secrets
- App/public URLs

## Notes
- `postgres.enabled=true` uses bundled Bitnami Postgres.
- Set `postgres.enabled=false` and `externalDatabase.*` for managed DB.
- Default exposure is Ingress + ClusterIP.

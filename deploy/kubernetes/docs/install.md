# Install Guide (Helm 3)

## Prerequisites
- Ingress controller — the chart creates Ingress resources but installs no controller (Step 1).
- Hatchet — must be deployed and reachable before Step 3 (Step 2).
- Storage — review `postgres.primary.persistence.size` and `storage.sharedWorkdir.size` before deploying to a small cluster, and reduce them if needed.
- Worker sandboxing — the `worker` deployment runs privileged with `SYS_ADMIN` and a `/sys/fs/cgroup` mount so review sandboxing can work. Clusters with restrictive pod security policies must allow this.

## 1) Install ingress controller
Once per cluster:
```bash
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update
helm upgrade --install nginx-ingress ingress-nginx/ingress-nginx -n ingress-nginx --create-namespace
```

For more information, see `docs/ingress-controller.md`

## 2) Install Hatchet
```bash
helm repo add hatchet https://hatchet-dev.github.io/hatchet-charts
helm upgrade --install hatchet-stack hatchet/hatchet-stack -f ./charts/profiles/hatchet-values.yaml
```

Verify before continuing:
```bash
kubectl get pods
kubectl get svc hatchet-stack-api hatchet-stack-engine
```

## 3) Bootstrap values
```bash
./scripts/init-values.sh
```

This script:
- creates `./charts/profiles/values.user.yaml` from the example if needed
- generates `JWT_SECRET`
- generates `TOKEN_ENCRYPTION_KEY`
- generates `LITELLM_MASTER_KEY`
- generates `WEB_TRIGGER_SECRET`
- attempts to generate `HATCHET_CLIENT_TOKEN` from the running Hatchet release

## 4) Configure values
Edit `./charts/profiles/values.user.yaml`:
- `global.registry`, `global.tag`
- `network.*` — the public origins, including `network.apiUrl` and `network.authUrl` (the OIDC issuer, must be https; auth v2 is the default auth mode, set `authV2.enabled: false` for legacy auth)
- `ingress.auth.tls.enabled` and `ingress.auth.tls.secretName` — the auth ingress must serve the https issuer with a certificate the web and api pods trust, since they call it server-side
- relevant provider specific API keys

You may also choose to use `secrets.mode=external`

### GPT-based models
If you use GPT for reviews, uncomment these settings in the chart values (see `charts/greptile/values.yaml`):
- `appConfig.reviewWorkflowRoutingEnabled` / `appConfig.defaultNativeRoutingPolicy`
- the matching `REVIEW_WORKFLOW_ROUTING_ENABLED` and `DEFAULT_NATIVE_ROUTING_POLICY` entries under `components.worker.componentEnv`

The GPT routing variant expects `gpt-5.5` by default. If `gpt-5.5` is not available from your provider, add a LiteLLM alias in `charts/greptile/files/llmproxy-config.yaml` that maps `gpt-5.5` to a GPT model you do have access to (under `router_settings.model_group_alias`).

## 5) Deploy
```bash
helm dependency update ./charts/greptile
helm upgrade --install greptile ./charts/greptile -f ./charts/profiles/values.user.yaml
```

## 6) Verify
```bash
kubectl get pods -l app.kubernetes.io/instance=greptile
kubectl get svc
kubectl get ingress
kubectl logs deploy/greptile-web
```

Minimum healthy set for a bundled-database install:
- `greptile-postgres`
- `greptile-pgbouncer`
- `greptile-redis`
- `greptile-api`
- `greptile-auth-v2`
- `greptile-hydra`
- `greptile-web`
- `greptile-webhook`
- `greptile-worker`
- `greptile-chunker`
- `greptile-jobs`
- `greptile-llmproxy`

With auth v2 (the default), `greptile-auth` is replaced by `greptile-auth-v2` and `greptile-hydra`.

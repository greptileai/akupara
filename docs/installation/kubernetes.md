# Install with Kubernetes

Helm 3 deployment for a Kubernetes cluster. Confirm [requirements](./requirements.md) first.

All commands below run from `deploy/kubernetes/` unless noted.

## Layout

- `charts/greptile` — Greptile application chart
- `charts/profiles` — values profiles, including `values.user.example.yaml`
- `scripts/` — validation and bootstrap helpers

The chart deploys Greptile workloads only: `web`, `auth`, `api`, `chunker`, `worker`, `webhook`, `jobs`, `llmproxy`, optional Jackson for SAML, and an optional bundled Postgres. Hatchet is installed separately.

## 1. Install an ingress controller

Greptile creates Ingress resources but does not install a controller. Install `ingress-nginx` once per cluster:

```bash
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update
helm upgrade --install nginx-ingress ingress-nginx/ingress-nginx \
  -n ingress-nginx \
  --create-namespace
```

Verify:

```bash
kubectl get pods -n ingress-nginx
kubectl get svc -n ingress-nginx
kubectl get ingressclass
```

Expected:

- An ingress class named `nginx`
- A controller service (`nginx-ingress-ingress-nginx-controller`) with endpoints

Then set:

```yaml
ingress:
  className: nginx
```

## 2. Install Hatchet

```bash
helm repo add hatchet https://hatchet-dev.github.io/hatchet-charts
helm upgrade --install hatchet-stack hatchet/hatchet-stack \
  -f ./charts/profiles/hatchet-values.yaml
```

Verify Hatchet is healthy before continuing:

```bash
kubectl get pods
kubectl get svc hatchet-stack-api hatchet-stack-engine
```

## 3. Bootstrap values

```bash
./scripts/validate.sh
./scripts/init-values.sh
```

`init-values.sh`:

- Creates `./charts/profiles/values.user.yaml` from the example if needed
- Generates `JWT_SECRET`
- Generates `TOKEN_ENCRYPTION_KEY`
- Generates `LITELLM_MASTER_KEY`
- Generates `WEB_TRIGGER_SECRET`
- Attempts to generate `HATCHET_CLIENT_TOKEN` from the running Hatchet release

Hatchet must already be deployed and reachable for automatic `HATCHET_CLIENT_TOKEN` generation to succeed.

## 4. Configure values

Edit `./charts/profiles/values.user.yaml` and set:

- `global.registry`, `global.tag`
- `network.appUrl` and `network.webhookUrl` — see [Networking](../configuration/networking.md)
- GitHub and model API keys — see [GitHub App creation](../configuration/github_app_creation.md) and [LLM providers](../configuration/llm-providers.md)
- Or switch to `secrets.mode=external`

### Feature flags

Set static boolean flags under `features.feature_flags`. The chart serializes the map into `FEATURE_FLAGS_JSON` in the shared ConfigMap, which every Greptile component receives.

```yaml
features:
  feature_flags:
    new-review-flow: true
    beta-summary: false
```

### Secrets modes

**Native (default):** `secrets.mode=native` with keys in `secrets.native.*`. Prefer `./scripts/init-values.sh` for fresh installs.

**External Secrets Operator:** set `secrets.mode=external` and configure `secrets.external.secretStoreRef` and `secrets.external.data`. The chart renders an `ExternalSecret` targeting the same secret name consumed by all workloads.

### Worker sandboxing

The `worker` deployment runs privileged with `SYS_ADMIN` and a `/sys/fs/cgroup` mount so review sandboxing can work. Clusters with restrictive pod security policies must allow this.

### Bundled database defaults

The chart includes PgBouncer with transaction pooling and basic timeout protections, plus a Postgres `idle_in_transaction_session_timeout` of `5min`. These are sensible defaults for fresh installs; they do not replace backups, monitoring, or capacity planning.

To use managed Postgres instead of the bundled chart, disable `postgres` and set `externalDatabase.*` in values.

## 5. Deploy Greptile

```bash
helm dependency update ./charts/greptile
helm upgrade --install greptile ./charts/greptile \
  -f ./charts/profiles/values.user.yaml
```

## 6. Verify rollout

```bash
kubectl get pods -l app.kubernetes.io/instance=greptile
kubectl get svc
kubectl get ingress
kubectl logs deploy/greptile-web
```

Minimum healthy set for a bundled-database install:

- `greptile-postgres`
- `greptile-pgbouncer`
- `greptile-api`
- `greptile-auth`
- `greptile-web`
- `greptile-webhook`
- `greptile-worker`
- `greptile-chunker`
- `greptile-jobs`
- `greptile-llmproxy`

Confirm Hatchet UI shows registered workers (`chunker`, `worker`).

## Next steps

- Configure and expose the right services: [Networking](../configuration/networking.md)
- If using GitHub, you need to create a GitHub App in your GitHub instance: [GitHub App creation](../configuration/github_app_creation.md)
- (Optional) Set up SSO for your organization: [SSO](../configuration/sso.md)

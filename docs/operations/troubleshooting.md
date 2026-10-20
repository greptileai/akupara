# Troubleshooting

Work through this checklist before opening a support request. Include service logs and Hatchet workflow status when you contact Greptile.

## Docker Compose

### 1. Service status

```bash
cd deploy/docker-compose
docker compose ps
```

Every service listed in the [Docker Compose install](../installation/docker-compose.md) should be running. Restart loops usually show up here first.

### 2. Service logs

```bash
docker compose logs <service_name>
```

Example:

```bash
docker compose logs greptile-web
```

Share error lines with Greptile support.

### 3. Workflow health

Open the Hatchet portal at `http://<your_server_ip>:8080` and look for workflows failing at a high rate (for example the reviews workflow).

### 4. LLM errors

All model calls go through the proxy:

```bash
docker compose logs greptile-llmproxy
```

Confirm API keys, base URLs, and any `gpt-5.5` aliases in `llmproxy-config.yaml`. See [LLM providers](../configuration/llm-providers.md).

## Kubernetes

### Rollout

```bash
kubectl get pods -l app.kubernetes.io/instance=greptile
kubectl get svc
kubectl get ingress
kubectl logs deploy/greptile-web
```

Confirm Hatchet UI shows registered workers (`chunker`, `worker`).

### Common symptoms

| Symptom | What to check |
|---------|----------------|
| `ImagePullBackOff` | `global.registry`, `global.tag`, and `global.imagePullSecrets` |
| `CrashLoopBackOff` | Container env and secret keys |
| DB migration job failed | DB connectivity and credentials |
| Worker review sandbox failed | `greptile-worker` is allowed to run privileged with `SYS_ADMIN` and mount `/sys/fs/cgroup` |
| No reviews generated | `HATCHET_CLIENT_TOKEN` and Hatchet API/gRPC endpoints |
| Login 502s or redirects to a pod hostname | The auth host's ingress needs `nginx.ingress.kubernetes.io/proxy-buffer-size: "16k"` — OAuth cookies exceed nginx's 4k default |
| `greptile-hydra` stuck in `Init` on a first install | It waits for the first database migration; check the logs of the `greptile-db-migration-1-*` jobs |
| `helm upgrade` times out while a migration job from an earlier revision is still running | That job holds the migration lock, and newer migration jobs wait behind it. Its logs show where it is stuck, usually a table lock held by another session. Clear the blocker and it finishes; otherwise it is stopped after an hour. A migration stopped mid-way leaves a failed migration that `prisma migrate resolve` must clear |
| Login hangs on a CGNAT cluster (pod CIDR `100.64.0.0/10`) | Hydra can't reach a 100.64 pod IP. Set `components.auth-v2.service.type: NodePort` with a pinned `nodePort`, and `authV2.hookUrl` to `http://<node-ip>:<nodePort>/api/hooks/token` |

### LLM errors

```bash
kubectl logs deploy/greptile-llmproxy
```

## Webhooks and URLs

If GitHub or GitLab events never reach Greptile:

- Confirm the public webhook URL from [Networking](../configuration/networking.md)
- Confirm the GitHub App webhook secret matches Greptile
- Confirm ingress or Caddy is routing `/webhook` to the webhook service
- Confirm only the intended ports are exposed (typically `3000` for web and `3007` for webhooks)

## SSO

If SAML login fails:

- Jackson must be served over HTTPS
- Jackson allowed redirect URLs must include the web origin and `<web>/login/saml`
- With auth v2 on Kubernetes, the allowed redirect URLs must also include `network.authUrl`; otherwise login returns 403 (`Redirect URL is not allowed`)
- `SamlConnection.saml_tenant_id` must match the Jackson tenant key, normally the user's email domain

See [SSO](../configuration/sso.md).

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
- `SamlConnection.tenant_id` must match the user's email domain

See [SSO](../configuration/sso.md).

# Scaling

## Recommended per app resources

Use the same value for requests and limits unless you have a reason to split them.

| Service | CPU | Memory |
|---------|-----|--------|
| `web` | 1 | 2 GiB |
| `api` | 2 | 4 GiB |
| `worker` | 2 | 4 GiB |
| `chunker` | 1 | 2 GiB |
| `jobs` | 1 | 2 GiB |
| `llmproxy` (LiteLLM) | 2 | 8 GiB |
| `webhook` | 1 | 2 GiB |
| `auth-v2` (legacy `auth`) | 250m (0.25) | 512 MiB |
| `hydra` | 100m (0.1) | 256 MiB |
| `redis` | 250m (0.25) | 512 MiB |
| `jackson` (SAML) | 250m (0.25) | 512 MiB |

`hydra` runs only with auth v2 (the default). `jackson` is deployed only when SSO is enabled. See [SSO](../configuration/sso.md).


## Worker capacity

The `worker` is the first bottleneck when scaling Greptile. Each worker pod handles up to **two concurrent reviews** by default.

Estimate replica count from peak concurrent pull-request reviews:

```text
worker replicas = concurrent PR reviews / 2
```

Round up. For example, 7 concurrent reviews needs 4 worker pods.

If there are not enough worker pods, Hatchet (the task queue) holds extra review jobs until a worker is free. Reviews still complete but they wait longer to start.


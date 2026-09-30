# Networking

Greptile needs a public application URL (the web UI) and a public webhook URL (GitHub and GitLab callbacks). Set both before you register a GitHub App or enable SSO.

Use an IP and port for a first install. For production, and for SSO, put a hostname and TLS in front of the same URLs.

## What each URL is for

| URL | Used by | Typical path |
|-----|---------|--------------|
| Application URL | Browser UI, OAuth callbacks, SSO redirects | `/` |
| Webhook URL | GitHub / GitLab event delivery | `/webhook` |

GitHub App callback and setup URLs are derived from the application URL. See [GitHub App creation](./github_app_creation.md).

## Docker Compose

### URLs

In `deploy/docker-compose/.env`:

```bash
IP_ADDRESS='<public_ip_or_hostname>'
APP_URL="http://${IP_ADDRESS}:3000"
NEXTAUTH_URL="${APP_URL}"
GREPTILE_WEBHOOK_URL='http://greptile-webhook:3007/webhook'
GITHUB_WEBHOOK_URL="${GREPTILE_WEBHOOK_URL}"
GITLAB_WEBHOOK_URL="${GREPTILE_WEBHOOK_URL}"
```

Notes:

- `APP_URL` / `NEXTAUTH_URL` must be the URL users and OAuth providers actually open. Use `https://<your_dns_name>` once a custom domain is in place.
- `GREPTILE_WEBHOOK_URL` is the in-cluster address used between Greptile services. External GitHub/GitLab webhooks should target the public webhook endpoint, for example `http://<ip_address>:3007/webhook` or `https://<your_dns_name>/webhook`.

Compose publishes several ports on all host interfaces. Restrict them with a host firewall.

**Expose externally:**

- `3000` — Greptile web UI
- `3007` — webhook receiver (GitHub / GitLab)
- `8080` — Hatchet admin UI
- `5225` — Jackson / SAML (only if you use SSO)

**Keep internal:**

- `5432` — PostgreSQL
- `5673` / `15673` — RabbitMQ AMQP and management UI
- `7077` — Hatchet gRPC
- `3001` — auth
- `3002` — API
- `4000` — LiteLLM proxy
- `8086` — jobs

### Custom domains (Caddy)

Docker Compose uses [Caddy](https://caddyserver.com/docs/) as the reverse proxy. Configuration lives in `deploy/docker-compose/Caddyfile`.

The default file routes:

- port `8080` → Hatchet
- port `3000` → `greptile-web`
- port `3007` → `greptile-webhook`
- port `5225` → `saml-jackson` (SSO)

To add a hostname for Greptile:

1. Create an A record: `<custom domain>` → the server's public IP.
2. Add a site block to the Caddyfile:

```
https://CustomGreptileDomain.com {
        handle /webhook* {
                reverse_proxy greptile-webhook:3007
        }
        handle /* {
                reverse_proxy greptile-web:3000
        }
}
```

Route `/webhook` to `greptile-webhook` before the catch-all. Otherwise `https://<your_dns_name>/webhook` hits the web UI and GitHub/GitLab deliveries never start reviews. You can instead keep webhooks on `http://<ip_address>:3007/webhook` or put them on a separate hostname.

3. Recreate Caddy:

```bash
docker compose --profile hatchet up --force-recreate -d hatchet-caddy
```

Update `APP_URL` and `NEXTAUTH_URL` in `.env` to the HTTPS hostname. Register the GitHub/GitLab webhook URL as `https://<your_dns_name>/webhook` if you use the `/webhook` handler above.

Caddy obtains certificates automatically with Let's Encrypt. That requires egress to the public internet. If the host cannot reach Let's Encrypt, configure TLS another way. Caddy supports [custom certificates](https://caddyserver.com/docs/caddyfile/directives/tls).

### SSO admin console

Jackson (BoxyHQ) requires HTTPS for the admin console. Add:

```
https://customJacksonDomain.com {
        handle /* {
                reverse_proxy saml-jackson:5225
        }
}
```

Then continue with [SSO](./sso.md).

### Grafana (optional)

The optional [observability stack](../operations/observability.md) publishes no host port. Serve Grafana through Caddy at `GRAFANA_URL`:

```
https://grafana.example.com {
        reverse_proxy greptile-lgtm:3000
}
```

## Kubernetes

### URLs

In `charts/profiles/values.user.yaml`:

```yaml
network:
  appUrl: "https://greptile.example.com"
  webhookUrl: "https://greptile.example.com/webhook"
  apiUrl: "https://greptile.example.com/api"
  authUrl: "https://auth.greptile.example.com" # must be https
```

`network.authUrl` is the OIDC issuer for auth v2 (the default auth mode) and must be https. The web and api pods call it server-side for token exchange and JWKS, so the auth ingress must serve a certificate they trust (`ingress.auth.tls`, or a private CA per [Custom certificate authorities](#custom-certificate-authorities)). `network.appUrl` must also be https under auth v2: Hydra rejects http OAuth redirect URIs on any host other than `localhost`, so serve the web host over TLS too (`ingress.web.tls`, or a TLS proxy in front of the ingress). Set `authV2.enabled: false` for legacy auth.

The chart creates three Ingress resources when `ingress.enabled` is true:

- **Web** — host and path default from `network.appUrl`
- **Auth** — host and path default from `network.authUrl`
- **Webhook** — host and path default from `network.webhookUrl`

Install an ingress controller before deploying. Greptile does not install one. See [Kubernetes install](../installation/kubernetes.md).

### Ingress hosts and TLS

You can override hosts and paths explicitly, and enable TLS by pointing each Ingress at a TLS secret:

```yaml
ingress:
  enabled: true
  className: nginx
  web:
    enabled: true
    host: ""
    path: /
    tls:
      enabled: true
      secretName: greptile-web-tls
  auth:
    enabled: true
    host: ""
    path: /
    tls:
      enabled: true
      secretName: greptile-auth-tls
  webhook:
    enabled: true
    host: ""
    path: /webhook
    tls:
      enabled: true
      secretName: greptile-webhook-tls
```

Create those secrets with cert-manager, your ingress controller's TLS support, or a manually issued certificate.

## Custom certificate authorities

Greptile services make server-side HTTPS calls to your auth URL, your SCM (GitHub Enterprise, GitLab, Gitea, Bitbucket Data Center), your SSO identity provider, and your LLM endpoints. If any of those present a certificate from a private CA, each calling service must trust that CA. Without it, calls fail with `UNABLE_TO_VERIFY_LEAF_SIGNATURE` (Node and Bun), `server certificate verification failed` (git), or `CERTIFICATE_VERIFY_FAILED` (Python).

The images use different runtimes, so the setting differs per service:

| Service | Base OS | Runtime | Setting |
| --- | --- | --- | --- |
| `web`, `auth-v2` | Debian 12 | Node (Next.js) | `NODE_EXTRA_CA_CERTS=<ca.pem>` |
| `api`, `webhook`, `jobs`, `auth` (legacy) | Debian 12 | Bun | `NODE_EXTRA_CA_CERTS=<ca.pem>` |
| `chunker`, `worker` | Debian 12 | Bun, git | `NODE_EXTRA_CA_CERTS=<ca.pem>` and `GIT_SSL_CAINFO=<ca.pem>` |
| `llmproxy` | Wolfi | Python 3.13 (LiteLLM) | `SSL_CERT_FILE=<bundle.pem>` |
| `jackson` (SAML) | Alpine 3.23 | Node 24 | `NODE_EXTRA_CA_CERTS=<ca.pem>` |
| `hydra` | Alpine 3.21 | Go | None. Its only outbound call is the token hook, which is plain `http://` (in-cluster by default, or the NodePort address from [Troubleshooting](../operations/troubleshooting.md) on CGNAT clusters). |
| `postgres`, `pgbouncer`, `redis`, `lgtm`, `db-migration` | — | — | None. They make no outbound calls to your services. |

What each setting does:

- `NODE_EXTRA_CA_CERTS` adds your CA to the runtime's built-in roots. Public endpoints keep working. Bun honors it the same way Node does. `api`, `webhook`, `jobs`, and `auth` ship no system CA bundle and no `update-ca-certificates`, so adding the CA to the OS trust store is not an option there.
- `GIT_SSL_CAINFO` is required for clones and fetches. git ignores `NODE_EXTRA_CA_CERTS` and `SSL_CERT_FILE`. A file containing only your CA is enough; git still trusts the system roots.
- `SSL_CERT_FILE` **replaces** LiteLLM's default (certifi) bundle. Point it at a bundle that contains the public roots and your CA, or calls to public LLM providers fail. Build one with `cat /etc/ssl/certs/ca-certificates.crt ca.pem > bundle.pem` (`/etc/ssl/cert.pem` on macOS).
- Python 3.13 enforces strict X.509 checks. `llmproxy` rejects a CA certificate that has no Key Usage extension (`CA cert does not include key usage extension`). Enterprise CAs normally include it. Hand-made test CAs often don't.

### Kubernetes

Store the CA, and the combined bundle if `llmproxy` needs it, in a ConfigMap in the Greptile release namespace:

```bash
roots=/etc/ssl/certs/ca-certificates.crt
[[ "$(uname)" == "Darwin" ]] && roots=/etc/ssl/cert.pem
cat "$roots" ca.pem > bundle.pem || rm bundle.pem
kubectl create configmap greptile-custom-ca --from-file=ca.pem --from-file=bundle.pem
```

Mount it and set the variable per component. `volumes` and `volumeMounts` are lists, so an override replaces the chart defaults. Copy a component's default entries from `values.yaml` into your override. `chunker`, `worker`, and `llmproxy` have defaults; the other components do not.

```yaml
components:
  web:
    componentEnv:
      NODE_EXTRA_CA_CERTS: /etc/greptile-ca/ca.pem
    volumes:
      - name: custom-ca
        configMap:
          name: greptile-custom-ca
    volumeMounts:
      - name: custom-ca
        mountPath: /etc/greptile-ca
        readOnly: true
  worker:
    componentEnv:
      NODE_EXTRA_CA_CERTS: /etc/greptile-ca/ca.pem
      GIT_SSL_CAINFO: /etc/greptile-ca/ca.pem
    volumes:
      - name: shared-workdir
        persistentVolumeClaim:
          claimName: ""
      - name: cgroupfs
        hostPath:
          path: /sys/fs/cgroup
          type: Directory
      - name: custom-ca
        configMap:
          name: greptile-custom-ca
    volumeMounts:
      - name: shared-workdir
        mountPath: /mnt/efs
      - name: cgroupfs
        mountPath: /sys/fs/cgroup
      - name: custom-ca
        mountPath: /etc/greptile-ca
        readOnly: true
  llmproxy:
    componentEnv:
      SSL_CERT_FILE: /etc/greptile-ca/bundle.pem
    volumes:
      - name: llmproxy-config
        configMap:
          name: ""
      - name: custom-ca
        configMap:
          name: greptile-custom-ca
    volumeMounts:
      - name: llmproxy-config
        mountPath: /app/config.yaml
        subPath: config.yaml
      - name: custom-ca
        mountPath: /etc/greptile-ca
        readOnly: true
```

Repeat the `web` block for `auth-v2` (`auth` when `authV2.enabled: false`), `api`, `webhook`, `jobs`, and `jackson` if SAML is enabled. For `chunker`, set the same variables as `worker` and add `custom-ca` next to its own default `shared-workdir` volume (mounted at `/mnt`); it has no `cgroupfs` mount. Restart the components after `helm upgrade`, because a ConfigMap change alone does not roll pods.

Check a service against an internal host:

```bash
kubectl exec deploy/greptile-worker -- bun -e 'console.log((await fetch("https://gitlab.internal.example.com")).status)'
kubectl exec deploy/greptile-worker -- git ls-remote https://gitlab.internal.example.com/group/repo.git
```

### Docker Compose

Put `ca.pem` and `bundle.pem` in `deploy/docker-compose/certs/` and add these lines to `.env`. Every Greptile service except `greptile-llmproxy` loads `.env`:

```bash
NODE_EXTRA_CA_CERTS='/etc/greptile-ca/ca.pem'
GIT_SSL_CAINFO='/etc/greptile-ca/ca.pem'
```

Mount the certificates, and set `SSL_CERT_FILE` on `greptile-llmproxy`, in a `docker-compose.override.yaml` next to `docker-compose.yaml`:

```yaml
services:
  greptile-web:
    volumes: ["./certs:/etc/greptile-ca:ro"]
  greptile-auth:
    volumes: ["./certs:/etc/greptile-ca:ro"]
  greptile-api:
    volumes: ["./certs:/etc/greptile-ca:ro"]
  greptile-webhook:
    volumes: ["./certs:/etc/greptile-ca:ro"]
  greptile-worker:
    volumes: ["./certs:/etc/greptile-ca:ro"]
  greptile-jobs:
    volumes: ["./certs:/etc/greptile-ca:ro"]
  greptile-indexer-chunker:
    volumes: ["./certs:/etc/greptile-ca:ro"]
  saml-jackson:
    volumes: ["./certs:/etc/greptile-ca:ro"]
  greptile-llmproxy:
    volumes: ["./certs:/etc/greptile-ca:ro"]
    environment:
      - SSL_CERT_FILE=/etc/greptile-ca/bundle.pem
```

## Checklist after changing URLs

1. Restart or roll the Greptile services so they pick up the new values.
2. Update the GitHub App homepage, callback, setup, and webhook URLs.
3. Update SSO allowed redirect URLs if SSO is enabled.
4. Confirm TLS certificates cover both hostnames if web and webhook use different domains.

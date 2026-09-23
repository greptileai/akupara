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

`network.authUrl` is the OIDC issuer for auth v2 (the default auth mode) and must be https. The web and api pods call it server-side for token exchange and JWKS, so the auth ingress must serve a certificate they trust (`ingress.auth.tls`). Set `authV2.enabled: false` for legacy auth.

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

## Checklist after changing URLs

1. Restart or roll the Greptile services so they pick up the new values.
2. Update the GitHub App homepage, callback, setup, and webhook URLs.
3. Update SSO allowed redirect URLs if SSO is enabled.
4. Confirm TLS certificates cover both hostnames if web and webhook use different domains.

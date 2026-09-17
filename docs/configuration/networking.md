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

By default the stack publishes `3000` (web), `3007` (webhook), and `8080` (Hatchet). Caddy also terminates TLS on `80`/`443` when you add hostname site blocks. Do not expose ports you do not need.

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
        handle /* {
                reverse_proxy greptile-web:3000
        }
}
```

3. Recreate Caddy:

```bash
docker compose --profile hatchet up --force-recreate -d hatchet-caddy
```

Update `APP_URL` and `NEXTAUTH_URL` in `.env` to the HTTPS hostname.

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

## Kubernetes

### URLs

In `charts/profiles/values.user.yaml`:

```yaml
network:
  appUrl: "https://greptile.example.com"
  webhookUrl: "https://greptile.example.com/webhook"
```

The chart creates two Ingress resources when `ingress.enabled` is true:

- **Web** — host and path default from `network.appUrl`
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

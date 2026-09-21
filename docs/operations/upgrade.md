# Upgrade

Greptile ships as versioned container images. Greptile provides the image tag for each release. Upgrade by moving to that tag, then rolling the stack.

Always take a database backup before upgrading. The bundled Postgres instance stores application metadata and vectors.

## Docker Compose

1. Confirm registry access still works:

   ```bash
   cd deploy/docker-compose
   ./bin/login-registry.sh
   ```

2. Set `GREPTILE_TAG` in `.env` to the tag Greptile gave you. Leave `HATCHET_TAG` unchanged unless the release notes say otherwise.

3. Pull and recreate Greptile services:

   ```bash
   ./bin/start-greptile.sh
   ```

4. Confirm containers are healthy:

   ```bash
   docker compose ps
   ```

Database migrations run as the `greptile-db-migration` service on startup. If that container exits non-zero, do not continue; see [Troubleshooting](./troubleshooting.md).


## Kubernetes

1. Update `global.tag` (and `global.registry` if needed) in `charts/profiles/values.user.yaml`.
2. Apply the chart:

   ```bash
   cd deploy/kubernetes
   helm dependency update ./charts/greptile
   helm upgrade --install greptile ./charts/greptile \
     -f ./charts/profiles/values.user.yaml
   ```

3. Watch the rollout:

   ```bash
   kubectl get pods -l app.kubernetes.io/instance=greptile
   helm status greptile
   ```

The chart runs a post-install / post-upgrade migration job and deletes it after success (`hook-succeeded`). `kubectl logs job/greptile-db-migration` is only available while the hook is running, or after a failure (the job is kept). A failed migration job means the new version did not finish applying schema changes; fix connectivity or credentials before retrying the upgrade.

Hatchet is a separate Helm release. Only upgrade `hatchet-stack` when the Greptile release notes require a newer Hatchet version, and keep `hatchet.*` URLs and `HATCHET_CLIENT_TOKEN` in sync.

### Migrating to auth v2

Auth v2 (OAuth) is the default auth mode. A legacy install upgrading without an auth origin fails with a message naming the required value. To switch:

1. Set `network.authUrl` (the https OIDC issuer) and `network.apiUrl` (public api origin). Give the auth ingress a certificate (`ingress.auth.tls`) that the web and api pods trust; they call the issuer server-side for token exchange and JWKS. See [Networking](../configuration/networking.md).
2. `helm upgrade`. This removes the legacy `greptile-auth` component and signs every user out — they re-authenticate through auth v2. Do it off-hours.

To stay on legacy auth, set `authV2.enabled: false`.

The four auth secrets (`CSRF_SECRET`, `HYDRA_SYSTEM_SECRET`, `HYDRA_WEB_CLIENT_SECRET`, `HYDRA_TOKEN_HOOK_SECRET`) generate on first install and persist across upgrades; `secrets.mode=external` must supply them (`HYDRA_WEB_CLIENT_SECRET` must be stable).

## After every upgrade

- Confirm the web UI loads at `APP_URL` / `network.appUrl`
- Confirm Hatchet shows registered `chunker` and `worker` workers
- Run a test pull request to verify webhooks and reviews still fire

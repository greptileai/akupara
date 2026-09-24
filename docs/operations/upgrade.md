# Upgrade

Greptile ships as versioned container images. Greptile provides the image tag for each release. Upgrade by moving to that tag, then rolling the stack.

Always take a database backup before upgrading. The bundled Postgres instance stores application metadata and vectors.

Check the release notes for the target tag before upgrading. Release notes list any new environment variables for that release. Apply every listed variable before you roll the stack. On Docker Compose, add them to `.env`. On Kubernetes, new chart defaults apply during `helm upgrade`; change `charts/profiles/values.user.yaml` when the release notes tell you to override a default.

## Docker Compose

1. Confirm registry access still works:

   ```bash
   cd deploy/docker-compose
   ./bin/login-registry.sh
   ```

2. Set `GREPTILE_TAG` in `.env` to the tag Greptile gave you. Leave `HATCHET_TAG` unchanged unless the release notes say otherwise.

3. Add any new environment variables listed in the release notes to `.env`.

4. Pull and recreate Greptile services:

   ```bash
   ./bin/start-greptile.sh
   ```

5. Confirm containers are healthy:

   ```bash
   docker compose ps
   ```

Database migrations run as the `greptile-db-migration` service on startup. If that container exits non-zero, do not continue; see [Troubleshooting](./troubleshooting.md).


## Kubernetes

1. Update `global.tag` (and `global.registry` if needed) in `charts/profiles/values.user.yaml`.
2. If the release notes list environment variable overrides, set them in `values.user.yaml`.
3. Apply the chart:

   ```bash
   cd deploy/kubernetes
   helm dependency update ./charts/greptile
   helm upgrade --install greptile ./charts/greptile \
     -f ./charts/profiles/values.user.yaml
   ```

4. Watch the rollout:

   ```bash
   kubectl get pods -l app.kubernetes.io/instance=greptile
   helm status greptile
   ```

Each install or upgrade runs the migration in two jobs that take turns on a database lock: `greptile-db-migration-<revision>` runs alongside the rollout and is deleted a day after it finishes, and the `greptile-db-migration` hook is what Helm waits for. The second to run finds nothing to apply, and a failed migration fails the release. The failure is in the logs of one of the two jobs (`helm history greptile` shows the revision). A failed migration job means the new version did not finish applying schema changes; fix connectivity or credentials before retrying the upgrade.

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

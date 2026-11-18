# Upgrade

Greptile ships as versioned container images and deployment scripts. Use the target release's deployment scripts and image tag, retaining your installation's configuration and secrets. For `202611.28`, updating the Kubernetes scripts/Helm chart is required; changing only the image tag is insufficient for usage export.

Always take a database backup before upgrading. The bundled Postgres instance stores application metadata and vectors.

Check the release notes for the target tag before upgrading. Release notes list any new environment variables for that release. Apply every listed variable before you roll the stack. On Docker Compose, add them to `.env`. On Kubernetes, new chart defaults apply during `helm upgrade`; change `charts/profiles/values.user.yaml` when the release notes tell you to override a default.

Before rolling out the [new review UI](https://www.greptile.com/blog/code-review-is-evolving), follow [Update an existing GitHub App for the review UI](../configuration/github_app_creation.md#update-an-existing-github-app-for-the-review-ui). This applies to both Docker Compose and Kubernetes. The app needs additional permissions and webhook subscriptions, and existing installations need owner approval; a Greptile upgrade does not grant them automatically.

## License key

All on-prem customers must configure `GREPTILE_LICENSE` for new installations and upgrades. Obtain the license key from your Greptile representative and keep it in your deployment's secret configuration. **If you do not have a license key, contact your Greptile representative before upgrading.**

**Kubernetes:** set the license in your existing `values.user.yaml`:

```yaml
secrets:
  native:
    GREPTILE_LICENSE: "<license-key-provided-by-Greptile>"
```

The chart stores this value in the shared application Secret and exposes it as `GREPTILE_LICENSE` to the Greptile services. With `secrets.mode: external`, add a mapping for the `GREPTILE_LICENSE` key to your existing `secrets.external.data` configuration instead, retaining the other secret mappings.

**Docker Compose:** add the following to your existing `deploy/docker-compose/.env`:

```dotenv
GREPTILE_LICENSE='<license-key-provided-by-Greptile>'
```

After setting or replacing the license, apply the Kubernetes values and restart the Greptile Deployments, or recreate the Greptile containers on Docker Compose, so the services load the updated environment. Keep real license keys out of source control.

## Daily usage export

The `jobs` service sends daily usage reports to `https://usage.greptile.com/usage-reports`. On Kubernetes, the sending Deployment is `greptile-jobs`, with pods named `greptile-jobs-…`.

1. Update the bundled Kubernetes scripts/Helm chart along with the container images. The chart creates a persistent installation-ID ConfigMap, injects `GREPTILE_INSTANCE_ID` into the services, and provisions the jobs checkpoint PVC. Preserve both resources across upgrades; configure `storage.jobsState.storageClass` or `storage.jobsState.existingClaim` for your cluster when needed.
2. Allow outbound HTTPS over **TCP port 443** from the jobs pods to **`usage.greptile.com`**. The hostname must resolve from the cluster.
3. Configure the [license key](#license-key) supplied by Greptile.
4. After upgrading, check the jobs logs for `usage_export.scheduled` and `usage_export.completed`. Reports run daily at **01:30 UTC** and on startup to send outstanding daily reports. Checkpoints advance after the receiver acknowledges a report.

Each report includes:

| Field | Contents |
| --- | --- |
| Human PR-author identifiers | SHA-256 hash, computed before transmission |
| Reviewed PR IDs | SHA-256 hash, computed before transmission |
| Daily review counts | Split by Base, Plus, Apex, and unknown effort where applicable |
| T-Rex | Review counts and standalone-run counts |
| Usage credits | Aggregate credits and reconciliation counters |
| Report metadata | Installation ID, application version, reporting dates, and report/integrity identifiers |
| Customer and license | Names, identifiers, status, and expiry when configured |

The usage report **does not include** any confidential data such as source code, diffs, PR titles or bodies.

If you have concerns about this export or the required network access, contact your **Greptile sales representative** for next steps before upgrading.

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

1. Obtain the target release's Kubernetes scripts/Helm chart, preserving your existing `charts/profiles/values.user.yaml` and secrets. Update `global.tag` (and `global.registry` if needed) in that values file. Do not apply only a new image tag to an older chart.
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

Each install or upgrade runs the migration in two jobs that take turns on a database lock: `greptile-db-migration-<revision>-<suffix>` runs alongside the rollout, and the `greptile-db-migration-<revision>-<suffix>-hook` hook is what Helm waits for. The second to run finds nothing to apply, and a failed migration fails the release. The failure is in the logs of one of the two jobs (`kubectl get jobs`; `helm history greptile` shows the revision). Jobs are deleted a day after they finish, and a migration job still running after an hour is stopped. A failed migration job means the new version did not finish applying schema changes; fix connectivity or credentials before retrying the upgrade.

Hatchet is a separate Helm release. Only upgrade `hatchet-stack` when the Greptile release notes require a newer Hatchet version, and keep `hatchet.*` URLs and `HATCHET_CLIENT_TOKEN` in sync.

### Migrating to auth v2

**Legacy auth is deprecated in `202611.28` and will be fully replaced by auth-v2 in the next self-hosted release. We encourage customers to migrate now.**

Auth v2 (OAuth) is the default auth mode. A legacy install upgrading without an auth origin fails with a message naming the required value. To switch:

1. Set `network.authUrl` (the https OIDC issuer) and `network.apiUrl` (public api origin). Give the auth ingress a certificate (`ingress.auth.tls`) that the web and api pods trust; they call the issuer server-side for token exchange and JWKS. See [Networking](../configuration/networking.md).
2. Set `authV2.enabled: true` and run `helm upgrade`. This removes the legacy `greptile-auth` component and signs every user out — they re-authenticate through auth v2. Do it off-hours.

For this release only, an existing installation can temporarily stay on legacy auth with `authV2.enabled: false`. Plan the migration before the next release; the new review UI does not require switching auth services in this release.

The four auth secrets (`CSRF_SECRET`, `HYDRA_SYSTEM_SECRET`, `HYDRA_WEB_CLIENT_SECRET`, `HYDRA_TOKEN_HOOK_SECRET`) generate on first install and persist across upgrades; `secrets.mode=external` must supply them (`HYDRA_WEB_CLIENT_SECRET` must be stable).

Self-hosted auth v2 disables email verification by default so existing password accounts can sign in without email delivery. Kubernetes sets `components.auth-v2.componentEnv.EMAIL_VERIFICATION_ENABLED: "false"`; when preparing a Docker Compose auth-v2 deployment, add `EMAIL_VERIFICATION_ENABLED=false` to your existing `.env` (new environments include it in `.env.example`). Set this to `true` only after configuring a working email provider. Password-reset emails still require email delivery.

## After every upgrade

- Confirm the web UI loads at `APP_URL` / `network.appUrl`
- Confirm Hatchet shows registered `chunker` and `worker` workers
- Run a test pull request to verify webhooks and reviews still fire

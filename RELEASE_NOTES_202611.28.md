# Greptile Self-Hosted 202611.28

This release enables the [new review UI](https://www.greptile.com/blog/code-review-is-evolving) at `<your_greptile_url>/pulls` with an updated review policy, deprecates legacy auth ahead of its replacement in the next release, and introduces daily usage export to Greptile.

## Before upgrading

- **Supported upgrade from:** validate `202610.5` → `202611.28` on the release candidate, including a fresh install and an upgrade of existing storage and configuration.
- **Upgrade urgency:** Recommended for deployments evaluating the new review UI.
- **Operator action:** Back up the database and deployment configuration, update the Kubernetes scripts/Helm chart and image tag, configure your license key, approve the GitHub App permission changes, and allow the usage-export network access described below. Plan your auth-v2 migration now.
- **Expected downtime:** less than 5 minutes

Follow the [upgrade guide](docs/operations/upgrade.md). The worker continues to use `bwrap` by default; preserve its sandbox permissions and mounts.

### License key required

Configure `GREPTILE_LICENSE` in your deployment's secrets before upgrading. **If you do not have a license key, contact your Greptile representative before upgrading.** See [license configuration](docs/operations/upgrade.md#license-key) for Kubernetes values and external-secret instructions.

### New review UI and review policy

Merge these values into your existing configuration, retaining other flags and overrides:

```yaml
global:
  tag: "202611.28"
appConfig:
  reviewWorkflowRoutingEnabled: "true"
  defaultNativeRoutingPolicy: "review-v5.4-no-diagrams@1"
features:
  feature_flags:
    effort-levels: true
    pr-detail-page: true
```

Ensure the LLM proxy can call `gpt-6.1-sol` and `gpt-6-luna`. The bundled proxy configuration includes these routes. Existing namespace routing overrides take precedence over the fleet default.

Update the existing [GitHub App permissions and events](docs/configuration/github_app_creation.md#update-an-existing-github-app-for-the-review-ui). Contents write enables code suggestions and merges; Administration read checks branch protection; Actions and Deployments read support CI and deployment context. Workflows write is optional for edits to workflow files. Installation owners must approve the changes. Users connect their SCM account to perform actions on their own behalf; their repository permissions still apply.

After the rollout, open `<your_greptile_url>/pulls`, run a review on a test PR, and verify viewing findings, posting a comment, and applying a suggestion.

### Daily usage export: Kubernetes and network updates required

The **`jobs` service** (`greptile-jobs` Deployment; pods named `greptile-jobs-…`) sends daily usage reports to Greptile at **`https://usage.greptile.com/usage-reports`**. Allow **outbound HTTPS over TCP port 443** from these pods to **`usage.greptile.com`**, and ensure the hostname resolves from the cluster. Export runs daily at 01:30 UTC and on service startup to send outstanding daily reports.

**You must update the bundled Kubernetes scripts/Helm chart as well as the images. Changing only the image tag is insufficient for usage export.** The updated chart creates and preserves the installation's unique ID in a ConfigMap, passes it to the services, and provisions persistent jobs checkpoint storage. Preserve the identity ConfigMap and jobs-state PVC on upgrades. The export destination is built in; customers do not need to configure it. See [daily usage export setup](docs/operations/upgrade.md#daily-usage-export).

The data sent outside your network includes:

- **SHA-256 hashes of human PR-author identifiers and IDs of PRs that received a code review.** Both identifier lists are hashed before transmission.
- **Daily completed code-review counts**, split by effort level: **Base, Plus, and Apex**; an unknown-effort count is included when applicable.
- **T-Rex usage counts**, including reviews with T-Rex and standalone T-Rex runs.
- Usage-credit totals and reconciliation counters, plus report metadata: installation ID, application version, reporting dates, report/integrity identifiers, and customer/license details (including names, identifiers, status, and expiry when configured).

The usage report does not include source code, diffs, PR titles or bodies, or raw PR-author and PR identifiers.

**If you have concerns about usage export or the required outbound connectivity, contact your Greptile sales representative to discuss next steps before upgrading.**

### Legacy auth is deprecated: migrate to auth-v2 now

**Legacy auth is deprecated in this release and will be fully replaced by auth-v2 in the next self-hosted release.** We encourage customers to migrate now using the existing [auth-v2 migration instructions](docs/operations/upgrade.md#migrating-to-auth-v2).

Legacy auth remains available for this release only with `authV2.enabled: false`; it is not required to switch auth services to try the review UI. Migrating to auth-v2 signs existing users out, so schedule the switch and follow the guide's DNS, HTTPS, and configuration requirements. Email verification is disabled by default for self-hosted auth-v2; password-reset emails still require email delivery.

## What's changed

### Highlights

- Add support for the new review UI and the `review-v5.4-no-diagrams@1` review policy.
- Export daily hashed usage metrics to Greptile from the jobs service.
- Deprecate auth service, auth-v2 and hydra replaces it.

See the [complete changelog](CHANGELOG.md).

## Release artifacts

- **Release date:** November 17, 2026.
- **Previous self-hosted release:** `202610.5` (October 12, 2026).
- **Container image tag:** `202611.28`.
- [Compatibility requirements](docs/installation/requirements.md)
- [Release manifest and image digests](release-manifest.json)
- **Rollback:** Rolling back to `202610.5` is possible, but restore the previous review variant and routing configuration alongside the image versions, including any repository or organization overrides. The newer review variant is incompatible with the older worker. Retain a pre-upgrade database backup; a complete review after restoring the previous variant has not yet been validated.

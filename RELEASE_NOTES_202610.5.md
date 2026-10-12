# Greptile Self-Hosted 202610.5

This release adds OpenAI GPT-based review policies and self-hosted Knowledge Base generation. It also introduces a required storage and configuration change for Knowledge Base users.

## Before upgrading

- **Supported upgrade from:** `202609.10`
- **Upgrade urgency:** Recommended
- **Operator action:** Take a database backup and review the Knowledge Base storage, model access, and environment requirements below before rolling the stack.
- **Expected downtime:** Plan a maintenance window; a specific downtime duration has not been separately validated.

Follow the [self-hosted upgrade guide](https://github.com/greptileai/akupara/blob/release/202610.5/docs/operations/upgrade.md).

### Upgrade notes

#### OpenAI review policies and review types

The default self-hosted review routing policy is now the OpenAI GPT-based `greptile-v5.3@6` policy. It supports the **Base**, **Plus**, and **Apex** review types when the `effort-levels` feature flag is enabled.

- `greptile-v5.3@6` requires access to `gpt-6.1-sol`, `gpt-6-sol`, `gpt-6-luna`, and `dsv4-flash-leased-nothink`.
- If your deployment does not have `gpt-6.1-sol`, set the default policy to `v5.2-tiers@2`; it requires `gpt-6-sol`, `gpt-5.6-luna`, and `dsv4-flash-leased-nothink`.
- Update any customized LiteLLM configuration with the supplied OpenAI routes and the `dsv4-flash-leased-nothink` alias. Configure `OPENAI_API_KEY` (or the equivalent credentials for your proxy).

For Docker Compose, set these in `.env`:

```bash
REVIEW_WORKFLOW_ROUTING_ENABLED=true
DEFAULT_NATIVE_ROUTING_POLICY=greptile-v5.3@6
FEATURE_FLAGS_JSON='{"effort-levels":true}'
```

For Kubernetes, set the equivalent chart values:

```yaml
appConfig:
  reviewWorkflowRoutingEnabled: "true"
  defaultNativeRoutingPolicy: "greptile-v5.3@6"
features:
  feature_flags:
    effort-levels: true
```

See [review variant selection](https://github.com/greptileai/akupara/blob/release/202610.5/docs/configuration/review-variants.md) for the supported policies, model routing, and verification instructions.

#### Knowledge Base

Knowledge Base is now available for self-hosted deployments. It requires all of the following:

1. **Persistent shared storage.** Knowledge Base artifacts are stored at `/var/lib/greptile/artifacts` and must be available to the web, API, worker, and jobs services. Docker Compose creates the persistent `knowledge_base` volume. The Helm chart creates a 100 GiB `ReadWriteMany` PVC by default; set `storage.knowledgeBase.size`, `storage.knowledgeBase.storageClass`, and `storage.knowledgeBase.accessModes` for your cluster, or provide an existing compatible claim. Preserve the `knowledge-base` volume and mount if you override a component's volume lists. See the [Helm storage defaults](https://github.com/greptileai/akupara/blob/release/202610.5/deploy/kubernetes/charts/greptile/values.yaml#L98-L108).
2. **Knowledge Base runtime configuration.** The standard 202610.5 Compose and Helm configuration provides these settings. Add them when you maintain a customized deployment manifest or environment configuration. See the [Helm environment defaults](https://github.com/greptileai/akupara/blob/release/202610.5/deploy/kubernetes/charts/greptile/values.yaml#L172-L181):

   ```bash
   # Shared by Greptile services
   KNOWLEDGE_BASE_SYNTHESIS_ENABLED='true'
   KNOWLEDGE_BASE_SYNTHESIS_DEFAULT_ENABLED='true'
   KNOWLEDGE_BASE_BUCKET='file:///var/lib/greptile/artifacts'
   KNOWLEDGE_BASE_MIN_REVIEW_COUNT='0'
   KNOWLEDGE_BASE_MATERIALIZATION_ENABLED='true'
   KNOWLEDGE_BASE_VIEWER_ENABLED='true'
   DEFAULT_KNOWLEDGE_BASE_ROUTING_POLICY='kb-gen-roll@5'
   # Refresh Knowledge Base documentation every day at 00:17 UTC.
   KNOWLEDGE_BASE_DOCS_CRON_EXPRESSION='17 0 * * *'
   KNOWLEDGE_BASE_DOCS_CRON_TIMEZONE='UTC'

   # Jobs service only
   FILE_CHANGE_ACTIVITY_ENABLED='true'
   FILE_CHANGE_ACTIVITY_BUCKET='file:///var/lib/greptile/artifacts'
   ```

3. **Model access.** Knowledge Base generation requires access to `gpt-5.6-terra` through your LLM proxy. If you do not have access to `gpt-5.6-terra` but would like to try Knowledge Base, contact your Greptile representative.

For user guidance, see the [official Knowledge Base guide](https://www.greptile.com/knowledge-base).

#### Billing environment variable

The web service now reads `BILLING`; it no longer reads `BILLING_ENABLED`. The standard Compose and Helm manifests are already updated. If you maintain a custom web deployment, replace `BILLING_ENABLED` with `BILLING` (normally `false` for self-hosted deployments). If the web pod is not updated, users can see incorrect banners stating that their trial has expired.

#### Other deployment changes

- The Gitea connection option is enabled by default.
- Under auth v2, `network.appUrl` must use HTTPS because Hydra rejects HTTP OAuth redirect URIs except on `localhost`.
- If internal SCM, SSO, or LLM endpoints use certificates signed by a private CA, follow the new [custom certificate authority configuration](https://github.com/greptileai/akupara/blob/release/202610.5/docs/configuration/networking.md#custom-certificate-authorities).

## What's changed

### Highlights

- Introduce OpenAI GPT-based review policies, with selectable Base, Plus, and Apex review types.
- Add self-hosted Knowledge Base generation and viewing, backed by a shared persistent artifact volume.
- Enable Gitea as an available connection option by default.

### Important fixes

- Respect automatic-approval settings configured on the base branch and safely withhold approval when those settings cannot be loaded.

See the [complete changelog](https://github.com/greptileai/akupara/blob/release/202610.5/CHANGELOG.md).

## Release artifacts

- **Release date:** October 12, 2026
- **Previous self-hosted release:** `202609.10`
- **Container image tag:** `202610.5` (designated immutable by the release owner)
- **Rollback:** An image-only rollback to `202609.10` is not supported after database migrations have run. Restore a database backup taken before the upgrade, then redeploy the prior release.
- [Compatibility requirements](https://github.com/greptileai/akupara/blob/release/202610.5/docs/installation/requirements.md)

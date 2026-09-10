# Secrets Modes

## Native Kubernetes Secret (default)
Use `secrets.mode=native` and set keys in `secrets.native.*`.

For fresh installs, prefer:
```bash
./scripts/init-values.sh
```

This bootstraps `charts/profiles/values.user.yaml` and auto-generates:
- `JWT_SECRET`
- `TOKEN_ENCRYPTION_KEY`
- `LITELLM_MASTER_KEY`
- `WEB_TRIGGER_SECRET`
- `HATCHET_CLIENT_TOKEN` when Hatchet is already deployed and reachable

## External Secrets Operator
Set `secrets.mode=external` and configure:
- `secrets.external.secretStoreRef`
- `secrets.external.data`

The chart renders an `ExternalSecret` targeting the same secret name consumed by all workloads.

In native mode the chart generates the keys below; in external mode your store
must supply them. The keys marked required are pulled by an explicit
`secretKeyRef`, so a missing one leaves the pod in `CreateContainerConfigError`
(feature-gated keys only when that feature is on):

Always required (llmproxy):
- `LITELLM_MASTER_KEY`, `LLM_PROXY_KEY`
- `ANTHROPIC_API_KEY`, `OPENAI_API_KEY`, `AZURE_OPENAI_API_KEY`
- `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`

Required when `authV2.enabled` (the default):
- `DIRECT_URL` (hydra's DSN), `CSRF_SECRET`, `HYDRA_SYSTEM_SECRET`, `HYDRA_TOKEN_HOOK_SECRET`
- `HYDRA_WEB_CLIENT_SECRET` — must stay stable across upgrades; rotating it desyncs the seeded web OAuth client

The remaining app secrets are consumed via `envFrom` (whole-secret) and so are
not required at container start, but the app needs them: `DATABASE_URL`,
`VECTOR_DB_URL`, `DB_PASSWORD`, `JWT_SECRET`,
`TOKEN_ENCRYPTION_KEY`, `WEB_TRIGGER_SECRET`, `WEBHOOK_SECRET`,
`HATCHET_CLIENT_TOKEN`, the `GITHUB_*` / `AUTH_GITHUB_*` keys, and `SMTP_PASSWORD`.

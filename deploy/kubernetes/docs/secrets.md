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
- `HATCHET_CLIENT_TOKEN` when Hatchet is already deployed and reachable

## External Secrets Operator
Set `secrets.mode=external` and configure:
- `secrets.external.secretStoreRef`
- `secrets.external.data`

The chart renders an `ExternalSecret` targeting the same secret name consumed by all workloads.

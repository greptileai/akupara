# Secrets Modes

## Native Kubernetes Secret (default)
Use `secrets.mode=native` and set keys in `secrets.native.*`.

## External Secrets Operator
Set `secrets.mode=external` and configure:
- `secrets.external.secretStoreRef`
- `secrets.external.data`

The chart renders an `ExternalSecret` targeting the same secret name consumed by all workloads.

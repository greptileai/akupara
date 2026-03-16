# Install Guide (Helm v2)

## 1) Install Ingress Controller (Required)
Install once per cluster:
```bash
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update
helm upgrade --install nginx-ingress ingress-nginx/ingress-nginx -n ingress-nginx --create-namespace
```

See also: `docs/ingress-controller.md`

## 2) Install Hatchet
```bash
helm repo add hatchet https://hatchet-dev.github.io/hatchet-charts
helm upgrade --install hatchet-stack hatchet/hatchet-stack -f ./charts/profiles/hatchet-values.yaml
```

## 3) Bootstrap Greptile values
Generate `values.user.yaml` and prepopulate required generated secrets:
```bash
./scripts/init-values.sh
```

This script:
- creates `./charts/profiles/values.user.yaml` from the example if needed
- generates `JWT_SECRET`
- generates `TOKEN_ENCRYPTION_KEY`
- generates `LITELLM_MASTER_KEY`
- attempts to generate `HATCHET_CLIENT_TOKEN` from the running Hatchet release

## 4) Configure Greptile values
Edit `./charts/profiles/values.user.yaml` and set:
- `global.registry`, `global.tag`
- `network.*`
- provider-specific secrets such as GitHub and model API keys
- or switch to `secrets.mode=external`

## 5) Deploy Greptile
```bash
helm dependency update ./charts/greptile
helm upgrade --install greptile ./charts/greptile -f ./charts/profiles/values.user.yaml
```

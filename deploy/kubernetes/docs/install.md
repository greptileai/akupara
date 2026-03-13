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

## 3) Generate/Set Hatchet Client Token
Create an API token in Hatchet admin UI and set `secrets.native.HATCHET_CLIENT_TOKEN`.

## 4) Configure Greptile values
Start from `./charts/profiles/values.user.example.yaml` and set:
- `global.registry`, `global.tag`
- `network.*`
- secrets (or switch to `secrets.mode=external`)

## 5) Deploy Greptile
```bash
helm dependency update ./charts/greptile
cp ./charts/profiles/values.user.example.yaml ./charts/profiles/values.user.yaml
helm upgrade --install greptile ./charts/greptile -f ./charts/profiles/values.user.yaml
```

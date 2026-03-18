# Ingress Controller Prerequisite

Greptile and Hatchet charts create Ingress resources, but they do not install an Ingress controller.

Install `ingress-nginx` once per cluster:

```bash
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update

helm upgrade --install nginx-ingress ingress-nginx/ingress-nginx \
  -n ingress-nginx \
  --create-namespace
```

Verify:

```bash
kubectl get pods -n ingress-nginx
kubectl get svc -n ingress-nginx
kubectl get ingressclass
```

Expected:
- an ingress class named `nginx`
- a controller service (`nginx-ingress-ingress-nginx-controller`) with endpoints

Then configure app charts to use:

```yaml
ingress:
  className: nginx
```

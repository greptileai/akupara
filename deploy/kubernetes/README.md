# Greptile Helm Deployment (v2)

This directory contains a clean-sheet Helm structure aligned with the current `deploy/docker-compose/` deployment behavior.

## Layout
- `charts/greptile`: Greptile app chart
- `charts/profiles`: values profiles/examples (including `values.user.example.yaml`)
- `docs/`: install, secrets, ops docs
- `scripts/`: validation and parity helpers

## Quick Start
```bash
cd deploy/kubernetes
./scripts/validate.sh
./scripts/init-values.sh
helm upgrade --install greptile ./charts/greptile -f ./charts/profiles/values.user.yaml
```

Read docs:
- `docs/install.md`
- `docs/ingress-controller.md`
- `docs/secrets.md`

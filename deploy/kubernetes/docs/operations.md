# Operations

## Verify rollout
```bash
kubectl get pods -l app.kubernetes.io/instance=greptile
kubectl logs deploy/greptile-greptile-web
```

## Validate worker registration
Check Hatchet UI for registered workers (`chunker`, `summarizer`, `worker`).

## Optional SAML
Enable `saml.enabled=true` and `components.jackson.enabled=true`, then provide Jackson secrets.

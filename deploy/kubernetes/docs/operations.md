# Operations

## Verify rollout
```bash
kubectl get pods -l app.kubernetes.io/instance=greptile
kubectl get svc
kubectl get ingress
kubectl logs deploy/greptile-web
```

## Validate worker registration
Check Hatchet UI for registered workers (`chunker`, `worker`).

## Optional SAML
Enable `saml.enabled=true` and `components.jackson.enabled=true`, then provide Jackson secrets.

## Migrating to auth v2
Auth v2 (OAuth) is the default auth mode. A legacy install upgrading without an auth
origin fails with a message naming the required value. To switch:
1. Set `network.authUrl` (the https OIDC issuer) and `network.apiUrl` (public api origin).
2. `helm upgrade`. This removes the legacy `greptile-auth` component and signs every user
   out — they re-authenticate through auth v2. Do it off-hours.

To stay on legacy auth, set `authV2.enabled: false`.

The four auth secrets (`CSRF_SECRET`, `HYDRA_SYSTEM_SECRET`, `HYDRA_WEB_CLIENT_SECRET`,
`HYDRA_TOKEN_HOOK_SECRET`) generate on first install and persist across upgrades;
`secrets.mode=external` must supply them (`HYDRA_WEB_CLIENT_SECRET` must be stable).

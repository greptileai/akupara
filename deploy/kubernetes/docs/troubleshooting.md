# Troubleshooting

- `ImagePullBackOff`: verify `global.registry`, `global.tag`, and `global.imagePullSecrets`.
- `CrashLoopBackOff`: inspect container env and secret keys.
- `DB migration job failed`: validate DB connectivity and credentials.
- `Worker review sandbox failed`: verify the `greptile-worker` pod is allowed to run privileged with `SYS_ADMIN` and mount `/sys/fs/cgroup`.
- `No reviews generated`: verify `HATCHET_CLIENT_TOKEN` and Hatchet endpoints.
- `Login 502s or redirects to a pod hostname`: the auth host's ingress needs `nginx.ingress.kubernetes.io/proxy-buffer-size: "16k"` — OAuth cookies exceed nginx's 4k default.
- `Login hangs on a CGNAT cluster (pod CIDR 100.64.0.0/10)`: hydra can't reach a 100.64 pod IP. Set `components.auth-v2.service.type: NodePort` with a pinned `nodePort`, and `authV2.hookUrl` to `http://<node-ip>:<nodePort>/api/hooks/token`.
- `SAML login 403 ("Redirect URL is not allowed")`: add `network.authUrl` to the SAML connection's redirectUrl allowlist.

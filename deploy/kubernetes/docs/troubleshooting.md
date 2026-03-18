# Troubleshooting

- `ImagePullBackOff`: verify `global.registry`, `global.tag`, and `global.imagePullSecrets`.
- `CrashLoopBackOff`: inspect container env and secret keys.
- `DB migration job failed`: validate DB connectivity and credentials.
- `Worker review sandbox failed`: verify the `greptile-worker` pod is allowed to run privileged with `SYS_ADMIN` and mount `/sys/fs/cgroup`.
- `No reviews generated`: verify `HATCHET_CLIENT_TOKEN` and Hatchet endpoints.

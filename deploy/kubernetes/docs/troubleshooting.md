# Troubleshooting

- `ImagePullBackOff`: verify `global.registry`, `global.tag`, and `global.imagePullSecrets`.
- `CrashLoopBackOff`: inspect container env and secret keys.
- `DB migration job failed`: validate DB connectivity and credentials.
- `No reviews generated`: verify `HATCHET_CLIENT_TOKEN` and Hatchet endpoints.

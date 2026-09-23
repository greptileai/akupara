# Observability

Greptile services emit traces, metrics, and logs over OTLP/HTTP whenever `OTEL_EXPORTER_OTLP_ENDPOINT` is set. When it is unset (the default) nothing is exported.

## Report to your own platform

Most deployments already run an observability platform. Point Greptile at its OTLP/HTTP collector and skip the rest of this page. The SDK appends `/v1/traces`, `/v1/metrics`, and `/v1/logs` to the base URL.

Kubernetes, in `values.user.yaml`:

```yaml
env:
  shared:
    OTEL_EXPORTER_OTLP_ENDPOINT: "http://otel-collector.example.com:4318"
```

Docker Compose, in `.env`:

```
OTEL_EXPORTER_OTLP_ENDPOINT='http://otel-collector.example.com:4318'
```

Add `OTEL_EXPORTER_OTLP_HEADERS` the same way if the collector needs auth headers.

## Bundled stack

If you have nowhere to send telemetry, both deployment methods can run an optional, off-by-default [Grafana LGTM](https://github.com/grafana/docker-otel-lgtm) stack: one container with an OpenTelemetry collector, Loki (logs), Tempo (traces), Prometheus (metrics), and Grafana with those datasources pre-provisioned. Enabling it runs the container and pins every Greptile service's `OTEL_EXPORTER_OTLP_ENDPOINT` to it. The endpoint is not configurable while the stack is enabled. To send telemetry elsewhere, disable the stack and use the section above.

Upstream describes the image as intended for development, demo, and testing environments. It runs as a single replica with local storage. Treat it as a built-in debugging console, not a monitoring platform.

### Kubernetes

In `values.user.yaml`:

```yaml
o11y:
  enabled: true

network:
  grafanaUrl: "https://grafana.example.com"
```

`./scripts/init-values.sh` generates `secrets.native.GF_SECURITY_ADMIN_PASSWORD`. In `secrets.mode=external` your store must supply that key. Then run `helm upgrade --install` as usual. Rendering fails if `env.shared` also sets `OTEL_EXPORTER_OTLP_ENDPOINT`.

Enabling or disabling the stack on a running install requires a full reroll after `helm upgrade`:

```bash
kubectl rollout restart deployment -l app.kubernetes.io/instance=greptile
```

The chart renders:

- Deployment and Service `<release>-lgtm` (ports 3000 Grafana, 4317 OTLP gRPC, 4318 OTLP HTTP)
- PersistentVolumeClaim `<release>-lgtm-data` sized by `o11y.persistence.size` (default 20Gi); set `o11y.persistence.enabled=false` for an emptyDir
- Ingress `<release>-grafana` on the host from `network.grafanaUrl`, which is also Grafana's `GF_SERVER_ROOT_URL`; set `ingress.grafana.enabled=false` to skip it and port-forward instead:

```bash
kubectl port-forward svc/greptile-lgtm 3000:3000
```

Log in as `admin` with the generated password.

### Docker Compose

In `.env`:

```
O11Y_ENABLED='true'
```

`./bin/start-greptile.sh` and `./bin/restart-greptile.sh` then add `docker-compose.o11y.yaml`, which runs the `greptile-lgtm` container and sets the endpoint on every Greptile service. Grafana listens on port 3030 (web owns 3000), with its root URL set to `http://${IP_ADDRESS}:3030`. Log in as `admin` with the `GF_SECURITY_ADMIN_PASSWORD` value from `.env.greptile-generated`. Data lives in the `lgtm_data` volume. Manual compose commands need both files (`docker compose -f docker-compose.yaml -f docker-compose.o11y.yaml ...`); `docker logs greptile-lgtm` works without them.

## What you will see

In Grafana Explore:

- Tempo: traces per service (`greptile-api`, `greptile-reviews` for the worker, `greptile-webhook`, `greptile-jobs`, `greptile-chunker`, `greptile-auth`, and `web`)
- Loki: `{service_name="greptile-reviews"}` for worker logs. Log lines carry `trace_id`, and the datasource links each one to its trace
- Prometheus: application metrics

Not instrumented: `llmproxy`, `auth-v2`, `hydra`, `jackson`, PgBouncer, Redis, and Postgres. Setting the endpoint on them is a no-op.

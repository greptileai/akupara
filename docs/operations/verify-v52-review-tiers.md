# Verify OpenAI review tiers

Use this guide after deploying an OpenAI review policy. It verifies the full path from Greptile's routing decision to the LLM provider without exposing source code, prompts, or API keys.

Two policies exist: `greptile-v5.3@6` and `v5.2-tiers@2`. `greptile-v5.3@6` is considered better, and Docker Compose and the Helm chart ship that policy. Use `v5.2-tiers@2` when the deployment does not have access to `gpt-6.1-sol` yet.

## Models each policy requires

Both policies call OpenAI. LiteLLM must expose the models for the policy set in `DEFAULT_NATIVE_ROUTING_POLICY`.

`greptile-v5.3@6` requires `gpt-6.1-sol`, `gpt-6-sol`, `gpt-6-luna`, and `dsv4-flash-leased-nothink`.

`v5.2-tiers@2` requires `gpt-6-sol`, `gpt-5.6-luna`, and `dsv4-flash-leased-nothink`.

`dsv4-flash-leased-nothink` is an alias. These configs forward it to `gpt-5.6-luna` with `reasoning_effort: low`. [`deploy/docker-compose/llmproxy-config.yaml`](../../deploy/docker-compose/llmproxy-config.yaml) and [`deploy/kubernetes/charts/greptile/files/llmproxy-config.yaml`](../../deploy/kubernetes/charts/greptile/files/llmproxy-config.yaml) show how the models and alias have to be configured in the LiteLLM config.

One LiteLLM file covers both policies. It needs a `gpt-6*` wildcard, an explicit `gpt-5.6-luna` entry, and the `dsv4-flash-leased-nothink` alias. The wildcard covers `gpt-6-sol`, `gpt-6.1-sol`, and `gpt-6-luna`. The wildcard, `gpt-5.6-luna`, and the alias use Responses API mode. The wildcard and `gpt-5.6-luna` allow `reasoning_effort`. The wildcard also allows `service_tier`, which `gpt-6.1-sol` forwards. Docker Compose and the Helm chart both route `acknowledged-judge` to `gpt-6-luna`.

## Expected configuration

The worker must receive these settings:

| Setting | Expected value |
| --- | --- |
| `FEATURE_FLAGS_JSON` | `{"effort-levels":true}` |
| `REVIEW_WORKFLOW_ROUTING_ENABLED` | `true` |
| `DEFAULT_NATIVE_ROUTING_POLICY` | `greptile-v5.3@6` |

Whitespace in `FEATURE_FLAGS_JSON` can differ between Compose and Helm. With `effort-levels` set to `true`, Base, Plus, and Apex are available. Set `effort-levels` to `false` to disable Plus and Apex for the whole instance. Every review then runs at Base, which limits inference cost.

`new-scm-ui` is unused. Leave it unset.

Set `DEFAULT_NATIVE_ROUTING_POLICY` to `v5.2-tiers@2` when the deployment does not have access to `gpt-6.1-sol` yet.

For Docker Compose:

```bash
docker compose exec greptile-worker sh -c \
  'printenv | grep -E "FEATURE_FLAGS_JSON|REVIEW_WORKFLOW_ROUTING_ENABLED|DEFAULT_NATIVE_ROUTING_POLICY"'
docker compose exec greptile-llmproxy sed -n '/^model_list:/,/^litellm_settings:/p' /app/config.yaml
```

For Kubernetes, `FEATURE_FLAGS_JSON` is in the shared ConfigMap. The routing settings are in the worker ConfigMap. These names match a release named `greptile`. The chart uses the release name when it already contains `greptile` (`my-greptile` creates `my-greptile-env`). Otherwise it prefixes the chart name (`prod` creates `prod-greptile-env`).

```bash
kubectl get configmap greptile-env -o yaml
kubectl get configmap greptile-worker-env -o yaml
kubectl get configmap greptile-llmproxy-config -o yaml
```

## Run an end-to-end check

1. Create a small disposable pull request.
2. Trigger a review as a Base, Plus, or Apex user. Repeat for each tier that you want to validate. With `effort-levels` set to `false`, only Base is available.
3. Record the review time and inspect the worker logs around that time.

Docker Compose:

```bash
docker compose logs --since=30m greptile-worker
```

Kubernetes, for a release named `greptile`:

```bash
kubectl logs deploy/greptile-worker --since=30m
```

Find the `ExperimentRouting resolved native review workflow` event. Confirm:

- `policy` matches `DEFAULT_NATIVE_ROUTING_POLICY`: `greptile-v5.3@6` or `v5.2-tiers@2`.
- For `v5.2-tiers@2`, `experiment` is the expected variant: Base `rk-v5.2-1c-v2`, Plus `rk-v5.2-3c`, or Apex `rk-v5.2-10c`.
- The logged `effort` and `params` match the selected tier.

Then find `Starting agent execution` for the same review. Confirm that it reports the expected `model` and `effort`. The main reviewer is `gpt-6.1-sol` on `greptile-v5.3@6` and `gpt-6-sol` on `v5.2-tiers@2`.

## Verify the provider request

Check LiteLLM for routing or provider errors:

```bash
docker compose logs --since=30m greptile-llmproxy
# or, for a release named greptile
kubectl logs deploy/greptile-llmproxy --since=30m
```

For definitive confirmation, inspect the audit log at your OpenAI-compatible provider or gateway. For the main reviewer, confirm:

- model: `gpt-6.1-sol` on `greptile-v5.3@6`, or `gpt-6-sol` on `v5.2-tiers@2`
- endpoint: `/v1/responses`
- `reasoning_effort`: the effort selected by the variant

For the context finder, confirm that `dsv4-flash-leased-nothink` is forwarded as `gpt-5.6-luna` with `reasoning_effort: low`.

LiteLLM logs identify failed routing and unsupported parameters, but the provider audit log is the only reliable evidence that the upstream service received and honored the requested reasoning level.

## If a check fails

- The worker result is missing `greptile-v5.3@6`, `v5.2-tiers@2`, or a `rk-v5.2-*` experiment for the `v5.2-tiers@2` policy: deploy the database migration that seeds that policy.
- Plus and Apex should be available, but every user gets Base: set `"effort-levels":true` in `FEATURE_FLAGS_JSON`.
- Plus and Apex should stay off to limit inference cost: set `"effort-levels":false` in `FEATURE_FLAGS_JSON`.
- LiteLLM reports a missing model or unsupported parameter: make sure the configured OpenAI-compatible endpoint exposes `gpt-6-sol`, `gpt-6.1-sol`, `gpt-6-luna`, and `gpt-5.6-luna`, accepts the `dsv4-flash-leased-nothink` alias, and supports the Responses API. The shipped configs do this with a `gpt-6*` wildcard plus the explicit `gpt-5.6-luna` entry and alias.

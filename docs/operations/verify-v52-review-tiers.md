# Verify v5.2 review tiers

Use this guide after deploying the `v5.2-tiers@2` review policy. It verifies the full path from Greptile's routing decision to the LLM provider without exposing source code, prompts, or API keys.

## Expected configuration

The worker must receive all three settings:

| Setting | Expected value |
| --- | --- |
| `FEATURE_FLAGS_JSON` | `{"effort-levels":true}` |
| `REVIEW_WORKFLOW_ROUTING_ENABLED` | `true` |
| `DEFAULT_NATIVE_ROUTING_POLICY` | `v5.2-tiers@2` |

The LiteLLM configuration must contain explicit `gpt-6-sol` and `gpt-5.6-luna` entries, plus the `dsv4-flash-leased-nothink` alias. The entries must allow `reasoning_effort` and use Responses API mode.

For Docker Compose:

```bash
docker compose exec greptile-worker sh -c \
  'printenv | grep -E "FEATURE_FLAGS_JSON|REVIEW_WORKFLOW_ROUTING_ENABLED|DEFAULT_NATIVE_ROUTING_POLICY"'
docker compose exec greptile-llmproxy sed -n '1,65p' /app/config.yaml
```

For Kubernetes, inspect the rendered worker environment and LiteLLM ConfigMap for the same values:

```bash
kubectl get configmap <release>-greptile-worker-env -o yaml
kubectl get configmap <release>-greptile-llmproxy-config -o yaml
```

## Run an end-to-end check

1. Create a small disposable pull request.
2. Trigger a review as a Base, Plus, or Apex user. Repeat for each tier that you want to validate.
3. Record the review time and inspect the worker logs around that time.

Docker Compose:

```bash
docker compose logs --since=30m greptile-worker
```

Kubernetes:

```bash
kubectl logs deployment/<release>-greptile-worker --since=30m
```

Find the `ExperimentRouting resolved native review workflow` event. Confirm:

- `policy` is `v5.2-tiers@2`.
- `experiment` is the expected variant: Base `rk-v5.2-1c-v2`, Plus `rk-v5.2-3c`, or Apex `rk-v5.2-10c`.
- The logged `effort` and `params` match the selected tier.

Then find `Starting agent execution` for the same review. Confirm that it reports the expected `model` and `effort`.

## Verify the provider request

Check LiteLLM for routing or provider errors:

```bash
docker compose logs --since=30m greptile-llmproxy
# or
kubectl logs deployment/<release>-greptile-llmproxy --since=30m
```

For definitive confirmation, inspect the audit log at your OpenAI-compatible provider or gateway. For the review agent, confirm:

- model: `gpt-6-sol`
- endpoint: `/v1/responses`
- `reasoning_effort`: the effort selected by the variant

For the context-finder alias, confirm that `dsv4-flash-leased-nothink` is forwarded as `gpt-5.6-luna` with `reasoning_effort: low`.

LiteLLM logs identify failed routing and unsupported parameters, but the provider audit log is the only reliable evidence that the upstream service received and honored the requested reasoning level.

## If a check fails

- Missing `v5.2-tiers@2` or `rk-v5.2-*` in the worker result: deploy the database migration that seeds the v5.2 policy and variants.
- The worker selects Base for every user: ensure `FEATURE_FLAGS_JSON` includes `"effort-levels":true`.
- LiteLLM reports a missing model or unsupported parameter: make sure the configured OpenAI-compatible endpoint exposes `gpt-6-sol` and `gpt-5.6-luna` and supports the Responses API.


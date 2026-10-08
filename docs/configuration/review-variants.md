# Self-hosted review variant selection

A Greptile review depends on two things:

1. **The LLM provider and the model.** For example, OpenAI with GPT or Anthropic with Claude Sonnet/Opus. (Provided by you)
2. **The prompt instructions and its structure.** We call this the **variant**. (Provided by Greptile)

We compare models and variants against each other with an internal eval system. For self-hosted deployments, the Anthropic policy is `rsv11`. Two OpenAI policies exist: `greptile-v5.3@6` and `v5.2-tiers@2`. `greptile-v5.3@6` is considered better. Use `v5.2-tiers@2` when the deployment does not have access to `gpt-6.1-sol` yet.

| Recommendation | Use when | Seeded routing policy |
| --- | --- | --- |
| Anthropic | Claude Sonnet 4.6 | `native-rsv11-stndrd4-expansion@3` |
| OpenAI | The deployment has access to `gpt-6.1-sol` | `greptile-v5.3@6` |
| OpenAI | The deployment does not have access to `gpt-6.1-sol` yet | `v5.2-tiers@2` |

These policies are seeded when the migration job runs. Pick one by setting the worker fleet default below. A namespace `routing.review` binding overrides this default for that namespace. The LiteLLM sections list the models each policy requires.

## Worker environment

Set these on the worker.

**Docker Compose** — set in `deploy/docker-compose/.env`:

```bash
REVIEW_WORKFLOW_ROUTING_ENABLED=true
DEFAULT_NATIVE_ROUTING_POLICY=greptile-v5.3@6
FEATURE_FLAGS_JSON='{"effort-levels":true}'
```

`FEATURE_FLAGS_JSON` is shared by every Greptile container. With `effort-levels` set to `true`, Base, Plus, and Apex are available. Set `effort-levels` to `false` to disable Plus and Apex for the whole instance. Every review then runs at Base, which limits inference cost.

Set `DEFAULT_NATIVE_ROUTING_POLICY` to `v5.2-tiers@2` when the deployment does not have access to `gpt-6.1-sol` yet. Docker Compose and the Helm chart ship that value.

Recreate the worker so it loads the environment. From `deploy/docker-compose`, run `./bin/restart-greptile.sh`, or `docker compose up -d --force-recreate greptile-worker`.

**Kubernetes** — set `appConfig` in chart values. The worker maps these onto `REVIEW_WORKFLOW_ROUTING_ENABLED` and `DEFAULT_NATIVE_ROUTING_POLICY`:

```yaml
appConfig:
  reviewWorkflowRoutingEnabled: "true"
  defaultNativeRoutingPolicy: "greptile-v5.3@6"
features:
  feature_flags:
    effort-levels: true
```

| Policy | `DEFAULT_NATIVE_ROUTING_POLICY` |
| --- | --- |
| rsv11 | `native-rsv11-stndrd4-expansion@3` |
| greptile-v5.3 | `greptile-v5.3@6` |
| v5.2 tiers | `v5.2-tiers@2` |

## LiteLLM: rsv11

`rsv11` is the Anthropic-based variant. It requires Claude Sonnet 4.6 and the following model alias to be set in litellm config.yaml:

| `model_name` the worker sends | Hosted alias | Upstream |
| --- | --- | --- |
| `review` | `review` → `claude-sonnet-4-6` | `claude-*` → `anthropic/claude-*`. |

`review` must be a `model_name` or `model_group_alias`. A model named `sonnet` does not receive this traffic. Point it at a Sonnet the deployment can call. This is required for every review.

`post-review-gate` is used only on a later review that already has Greptile comments. It is optional but highly recommended: a missing route fails open and the review still posts.

| `model_name` | Hosted alias | Upstream |
| --- | --- | --- |
| `post-review-gate` | `post-review-gate` → `gpt-5.4-nano` | `gpt-*` → OpenAI. Alternatively: `claude-haiku` → `claude-haiku-4-5-20251001` |

```yaml
model_group_alias:
  review: claude-sonnet-4-6
  # optional, later reviews only
  post-review-gate: gpt-5.4-nano
```

`claude-sonnet-4-6` still needs a `model_list` route, such as the `claude-*` wildcard or a Bedrock model id.

## LiteLLM: OpenAI policies

`greptile-v5.3@6` and `v5.2-tiers@2` call OpenAI. They do not call `review` or `post-review-gate`.

`greptile-v5.3@6` requires `gpt-6.1-sol`, `gpt-6-sol`, `gpt-6-luna`, and `dsv4-flash-leased-nothink`.

`v5.2-tiers@2` requires `gpt-6-sol`, `gpt-5.6-luna`, and `dsv4-flash-leased-nothink`.

`dsv4-flash-leased-nothink` is an alias. These configs forward it to `gpt-5.6-luna` with `reasoning_effort: low`. A `gpt-6*` wildcard covers `gpt-6-sol`, `gpt-6.1-sol`, and `gpt-6-luna`, and `gpt-5.6-luna` stays an explicit entry. The wildcard, `gpt-5.6-luna`, and the alias use Responses API mode. [`deploy/docker-compose/llmproxy-config.yaml`](../../deploy/docker-compose/llmproxy-config.yaml) and [`deploy/kubernetes/charts/greptile/files/llmproxy-config.yaml`](../../deploy/kubernetes/charts/greptile/files/llmproxy-config.yaml) show how the models and alias have to be configured in the LiteLLM config.

To verify a deployment, see [Verify OpenAI review tiers](../operations/verify-v52-review-tiers.md).

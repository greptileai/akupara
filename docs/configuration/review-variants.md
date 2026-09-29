# Self-hosted review variant selection

A Greptile review depends on two things:

1. **The LLM provider and the model.** For example, OpenAI with GPT or Anthropic with Claude Sonnet/Opus. (Provided by you)
2. **The prompt instructions and its structure.** We call this the **variant**. (Provided by Greptile)

We compare new models and variants against each other with an internal eval system. From those comparisons, we currently recommend two variants for self-hosted deployments:

| Recommendation | Use when the deployment serves | Variant | Seeded routing policy |
| --- | --- | --- | --- |
| Anthropic | Claude Sonnet 4.6 or better | rsv11 | `native-rsv11-stndrd4-expansion@3` |
| OpenAI | GPT 5.6 | greptile-v5 | `greptile-v5point1@2` |

Both policies are already seeded when the migration job runs. Pick one by setting the worker fleet default below. A namespace `routing.review` binding overrides this default for that namespace. The LiteLLM sections list the model names each variant sends, and the aliases the proxy must define so those names reach the provider above.

## Worker environment

Set these on the worker for either policy.

**Docker Compose** — set in `deploy/docker-compose/.env`:

```bash
REVIEW_WORKFLOW_ROUTING_ENABLED=true
DEFAULT_NATIVE_ROUTING_POLICY=<one of the policies below>
```

Recreate the worker so it loads the new environment. From `deploy/docker-compose`, run `./bin/restart-greptile.sh`, or `docker compose up -d --force-recreate greptile-worker`.

**Kubernetes** — uncomment in chart values:

- `appConfig.reviewWorkflowRoutingEnabled` set to `"true"`
- `appConfig.defaultNativeRoutingPolicy` set to one of the policies below
- The matching `REVIEW_WORKFLOW_ROUTING_ENABLED` and `DEFAULT_NATIVE_ROUTING_POLICY` entries under `components.worker.componentEnv`

Those worker entries are commented out. Setting only `appConfig` does not pass the variables to the worker.

| Variant     | `DEFAULT_NATIVE_ROUTING_POLICY`    | Harness     |
| ----------- | ---------------------------------- | ----------- |
| rsv11       | `native-rsv11-stndrd4-expansion@3` | Claude Code |
| greptile-v5 | `greptile-v5point1@2`              | OpenCode    |

## LiteLLM: rsv11

`rsv11` is the Anthropic-based variant. It requires Claude Sonnet 4.6 or later and the following model alias to be set in litellm config.yaml:

| `model_name` the worker sends | Hosted alias                        | Upstream                                                                                                      |
| ----------------------------- | ----------------------------------- | ------------------------------------------------------------------------------------------------------------- |
| `review`                      | `review` → `claude-sonnet-4-6`      | `claude-*` → `anthropic/claude-*`.    |

`review` must be a `model_name` or `model_group_alias`. A model named `sonnet` does not receive this traffic. Point it at a Sonnet the deployment can call. This is required for every review.

`post-review-gate` is used only on a later review that already has Greptile comments. It is optional but highly recommended: a missing route fails open and the review still posts.

| `model_name`       | Hosted alias                         | Upstream                                                                          |
| ------------------ | ------------------------------------ | --------------------------------------------------------------------------------- |
| `post-review-gate` | `post-review-gate` → `gpt-5.4-nano`  | `gpt-*` → OpenAI. Alternatively: `claude-haiku` → `claude-haiku-4-5-20251001`         |

```yaml
model_group_alias:
  review: claude-sonnet-4-6
  # optional, later reviews only
  post-review-gate: gpt-5.4-nano
```

`claude-sonnet-4-6` still needs a `model_list` route, such as the `claude-*` wildcard or a Bedrock model id.

## LiteLLM: greptile-v5

`greptile-v5` is the OpenAI-based variant. It requires these GPT 5.6 models:

- `gpt-5.6-sol`
- `gpt-5.6-luna`
- `gpt-5.6-terra`
- `dsv4-flash-leased-nothink` (this is a model alias that needs to reference either Deepseek v4 flash or gpt-5.6-luna)

Unlike `rsv11`, `greptile-v5` does not call `review` or `post-review-gate`.

```yaml
model_list:
  - model_name: gpt-*
    litellm_params:
      model: openai/gpt-*
      api_base: os.environ/OPENAI_BASE_URL
      api_key: os.environ/OPENAI_API_KEY
  - model_name: dsv4-flash-leased-nothink
    litellm_params:
      model: openai/gpt-5.6-luna
      api_base: os.environ/OPENAI_BASE_URL
      api_key: os.environ/OPENAI_API_KEY
      reasoning_effort: low
      allowed_openai_params: [reasoning_effort]
```


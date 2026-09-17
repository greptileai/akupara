# LLM providers

Greptile sends model traffic through an internal LiteLLM proxy (`greptile-llmproxy`). Configure provider credentials and, if needed, model aliases. If you already maintain your own LiteLLM proxy, you can skip deploying Greptile's proxy and reuse your instance. In that case, define the same model aliases as in Greptile's LiteLLM [config.yaml](../../deploy/docker-compose/llmproxy-config.yaml) and point `LLM_PROXY_BASE_URL` at your proxy.

## Supported providers

- Anthropic (required unless you use Bedrock for the same models)
- OpenAI
- Azure AI Foundry
- AWS Bedrock

Recommended rate limits: at least 100 requests per minute and 800,000 tokens per minute.

## Docker Compose

Set keys and base URLs in `deploy/docker-compose/.env`. Leave unused providers untouched.

```bash
# Anthropic
ANTHROPIC_BASE_URL='https://api.anthropic.com'
ANTHROPIC_KEY='sk-ant-secret_key'

# OpenAI
OPENAI_API_BASE_URL='https://api.openai.com/v1/'
OPENAI_KEY='sk-openai_key'

# Azure OpenAI
AZURE_OPENAI_URL='https://onboardai.openai.azure.com/'
AZURE_OPENAI_KEY='azure_key'
AZURE_OPENAI_API_VERSION='2024-07-18'

# AWS Bedrock
AWS_ACCESS_KEY_ID='aws_access_key'
AWS_SECRET_ACCESS_KEY='aws_secret_key'
AWS_REGION='us-east-1'
```

For Bedrock, create a long-term access key under **AWS Bedrock > API Keys > Long-term API Keys** first.

Model routing lives in `deploy/docker-compose/llmproxy-config.yaml`. Bedrock and Azure examples are commented in that file; uncomment and adjust `model_list` entries to match the models you have access to.

## Kubernetes

Put API keys in `secrets.native.*` (or your external secret store):

- `ANTHROPIC_KEY` (required for default Anthropic routing)
- `OPENAI_KEY`
- `AZURE_OPENAI_KEY`
- `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY`

LiteLLM config is `charts/greptile/files/llmproxy-config.yaml`. Chart values also expose `llm.anthropicBaseUrl`, `llm.openaiBaseUrl`, and `llm.azureOpenaiUrl`.

## GPT-based review routing

If you use GPT for reviews, enable the GPT routing variant.

**Docker Compose** — uncomment in `.env`:

```bash
REVIEW_WORKFLOW_ROUTING_ENABLED=true
DEFAULT_NATIVE_ROUTING_POLICY=native-rod-gpt-simp-v6-composed-primary@1
```

**Kubernetes** — uncomment in chart values:

- `appConfig.reviewWorkflowRoutingEnabled` / `appConfig.defaultNativeRoutingPolicy`
- The matching `REVIEW_WORKFLOW_ROUTING_ENABLED` and `DEFAULT_NATIVE_ROUTING_POLICY` entries under `components.worker.componentEnv`

The GPT variant expects `gpt-5.5` by default. If `gpt-5.5` is not available from your provider, add a LiteLLM alias under `router_settings.model_group_alias` mapping `gpt-5.5` to a GPT model you do have:

```yaml
router_settings:
  model_group_alias:
    "gpt-5.5": "gpt-5.2"
```

## Debugging LLM calls

All provider calls go through `greptile-llmproxy`. When reviews fail with model errors, inspect that service first. See [Troubleshooting](../operations/troubleshooting.md).

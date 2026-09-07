---
layout: default
title: Provider Setup and Custom Endpoints
parent: Configuration
nav_order: 1
description: Per-provider API keys, organization headers, Bedrock and Vertex AI authentication, and OpenAI-compatible custom endpoints.
---

# {{ page.title }}

{{ page.description }}
{: .fs-6 .fw-300 }

After reading this guide, you will know:

* How to configure API keys for every supported provider.
* How to set OpenAI organization and project headers.
* How to authenticate with Bedrock credential providers and Vertex AI service accounts.
* How to connect to OpenAI-compatible and custom endpoints.

## API Keys

Configure API keys only for the providers you use. RubyLLM won't complain about missing keys for providers you never touch.

RubyLLM resolves the provider from the model registry. Pass `provider:` when you want another host for that model or use a custom deployment. See [Model Resolution]({% link _reference/model-resolution.md %}).

```ruby
RubyLLM.configure do |config|
  # Anthropic
  config.anthropic_api_key = ENV['ANTHROPIC_API_KEY']
  config.anthropic_api_base = ENV['ANTHROPIC_API_BASE'] # optional custom Anthropic endpoint

  # Azure
  config.azure_api_base = ENV['AZURE_API_BASE'] # Azure OpenAI or Foundry resource endpoint
  config.azure_api_key = ENV['AZURE_API_KEY'] # use this or
  config.azure_ai_auth_token = ENV['AZURE_AI_AUTH_TOKEN'] # this

  # Bedrock
  config.bedrock_api_key = ENV['AWS_ACCESS_KEY_ID']
  config.bedrock_secret_key = ENV['AWS_SECRET_ACCESS_KEY']
  config.bedrock_region = ENV['AWS_REGION'] # Required for Bedrock
  config.bedrock_session_token = ENV['AWS_SESSION_TOKEN'] # For temporary credentials
  # config.bedrock_credential_provider = Aws::InstanceProfileCredentials.new # Optional Aws::CredentialProvider
  config.bedrock_api_base = ENV['BEDROCK_API_BASE'] # optional custom Bedrock endpoint
  config.bedrock_mantle_api_base = ENV['BEDROCK_MANTLE_API_BASE'] # optional custom bedrock-mantle endpoint
  config.bedrock_batch_s3_uri = ENV['BEDROCK_BATCH_S3_URI'] # s3://bucket/prefix for batches and large attachments
  config.bedrock_batch_role_arn = ENV['BEDROCK_BATCH_ROLE_ARN'] # IAM role Bedrock assumes for batch jobs
  config.bedrock_video_s3_uri = ENV['BEDROCK_VIDEO_S3_URI'] # s3://bucket/prefix for generated videos

  # Cohere
  config.cohere_api_key = ENV['COHERE_API_KEY']
  config.cohere_api_base = ENV['COHERE_API_BASE'] # optional custom Cohere endpoint

  # Deepgram
  config.deepgram_api_key = ENV['DEEPGRAM_API_KEY']
  config.deepgram_api_base = ENV['DEEPGRAM_API_BASE'] # Optional, for self-hosted deployments

  # DeepSeek
  config.deepseek_api_key = ENV['DEEPSEEK_API_KEY']
  config.deepseek_api_base = ENV['DEEPSEEK_API_BASE'] # optional custom DeepSeek endpoint

  # ElevenLabs
  config.elevenlabs_api_key = ENV['ELEVENLABS_API_KEY']
  config.elevenlabs_api_base = ENV['ELEVENLABS_API_BASE'] # Optional, for the regional residency endpoints

  # Gemini
  config.gemini_api_key = ENV['GEMINI_API_KEY']
  config.gemini_api_base = ENV['GEMINI_API_BASE'] # optional API version override

  # GPUStack
  config.gpustack_api_base = ENV['GPUSTACK_API_BASE']
  config.gpustack_api_key = ENV['GPUSTACK_API_KEY']

  # Mistral
  config.mistral_api_key = ENV['MISTRAL_API_KEY']
  config.mistral_api_base = ENV['MISTRAL_API_BASE'] # optional custom Mistral endpoint

  # Ollama
  config.ollama_api_base = 'http://localhost:11434/v1'
  config.ollama_api_key = ENV['OLLAMA_API_KEY'] # optional for authenticated/remote Ollama endpoints

  # Ollama Cloud
  config.ollama_cloud_api_key = ENV['OLLAMA_CLOUD_API_KEY'] # Key from ollama.com/settings/keys
  config.ollama_cloud_api_base = ENV['OLLAMA_CLOUD_API_BASE'] # Optional, defaults to https://ollama.com/v1

  # OpenAI
  config.openai_api_key = ENV['OPENAI_API_KEY']
  config.openai_api_base = ENV['OPENAI_API_BASE'] # Optional custom OpenAI-compatible endpoint

  # OpenRouter
  config.openrouter_api_key = ENV['OPENROUTER_API_KEY']
  config.openrouter_api_base = ENV['OPENROUTER_API_BASE'] # optional custom OpenRouter endpoint
  config.openrouter_app_url = 'https://myapp.com' # Optional app attribution for OpenRouter rankings
  config.openrouter_app_name = 'My App' # Optional app display name in OpenRouter rankings

  # Perplexity
  config.perplexity_api_key = ENV['PERPLEXITY_API_KEY']
  config.perplexity_api_base = ENV['PERPLEXITY_API_BASE'] # optional custom Perplexity endpoint

  # Vertex AI
  config.vertexai_project_id = ENV['GOOGLE_CLOUD_PROJECT']
  config.vertexai_location = ENV['GOOGLE_CLOUD_LOCATION']
  config.vertexai_service_account_key = ENV['VERTEXAI_SERVICE_ACCOUNT_KEY'] # Optional: service account JSON key
  config.vertexai_api_base = ENV['VERTEXAI_API_BASE'] # optional custom Vertex AI endpoint
  config.vertexai_ranking_api_base = ENV['VERTEXAI_RANKING_API_BASE'] # optional Discovery Engine endpoint
  config.vertexai_ranking_config = ENV['VERTEXAI_RANKING_CONFIG'] # optional full rankingConfig resource name
  config.vertexai_batch_gcs_uri = ENV['VERTEXAI_BATCH_GCS_URI'] # gs://bucket/prefix for batches and large attachments

  # xAI
  config.xai_api_key = ENV['XAI_API_KEY']
  config.xai_api_base = ENV['XAI_API_BASE'] # optional custom xAI endpoint
end
```

> Attempting to use an unconfigured provider will raise `RubyLLM::ConfigurationError`. Only configure what you need.
{: .note }

## Ollama Cloud

Ollama Cloud runs the large open models on Ollama's servers. It speaks the same wire format as local Ollama, but it lives at `https://ollama.com/v1` and requires a key, so it is a separate provider:

```ruby
RubyLLM.configure do |config|
  config.ollama_cloud_api_key = ENV['OLLAMA_CLOUD_API_KEY'] # ollama.com/settings/keys
end

RubyLLM.chat(model: 'gpt-oss:120b', provider: :ollama_cloud).ask('Hello from Ollama Cloud')
```

Because `:ollama` and `:ollama_cloud` are separate providers, you can point one at your own machine and the other at the hosted service in the same process:

```ruby
RubyLLM.configure do |config|
  config.ollama_api_base = 'http://localhost:11434/v1'
  config.ollama_cloud_api_key = ENV['OLLAMA_CLOUD_API_KEY']
end

RubyLLM.chat(model: 'qwen3', provider: :ollama)              # your GPU
RubyLLM.chat(model: 'gpt-oss:120b', provider: :ollama_cloud) # Ollama's GPUs
```

Model names differ between the two. Locally, cloud models carry a `-cloud` suffix (`gpt-oss:120b-cloud`) because your Ollama offloads them; the hosted API serves the plain name (`gpt-oss:120b`). Use the plain name with `:ollama_cloud`.

Ollama retires cloud models regularly, so the shipped registry lags what the service serves today. RubyLLM accepts any model ID you give `:ollama_cloud` without a registry entry, and `refresh` pulls the live catalog:

```ruby
RubyLLM.models.refresh
RubyLLM.models.by_provider(:ollama_cloud).map(&:id)
```

Ollama Cloud does not support [structured output]({% link _core_features/structured-output.md %}); use local Ollama or another provider when you need a schema.

## Bedrock Credential Providers

For IAM roles, assume-role flows, and rotating credentials, configure an AWS SDK credential provider instead of static keys:

```ruby
require 'aws-sdk-core'

RubyLLM.configure do |config|
  config.bedrock_region = 'us-east-1'
  config.bedrock_credential_provider = Aws::InstanceProfileCredentials.new
end
```

`bedrock_credential_provider` can be any object that responds to `#credentials`, including `Aws::AssumeRoleCredentials` and `Aws::SharedCredentials`. When it is set, RubyLLM uses it instead of `bedrock_api_key`, `bedrock_secret_key`, and `bedrock_session_token`.

## Bedrock Converse and Mantle Endpoints

RubyLLM selects the Bedrock endpoint from the model registry. Converse and Mantle use the same credentials and region.

For a custom endpoint, set `bedrock_api_base` for Converse or `bedrock_mantle_api_base` for Mantle. See [Model Resolution]({% link _reference/model-resolution.md %}) for protocol selection.

### Guardrails

To use [moderation]({% link _core_features/moderation.md %}) with Bedrock, configure an existing guardrail and give your credentials permission to apply it:

```ruby
RubyLLM.configure do |config|
  config.bedrock_guardrail_id = ENV.fetch("BEDROCK_GUARDRAIL_ID")
  config.bedrock_guardrail_version = ENV.fetch("BEDROCK_GUARDRAIL_VERSION")
end
```

## OpenAI Organization & Project Headers

For OpenAI users with multiple organizations or projects:

```ruby
RubyLLM.configure do |config|
  config.openai_api_key = ENV['OPENAI_API_KEY']
  config.openai_organization_id = ENV['OPENAI_ORG_ID']  # Billing organization
  config.openai_project_id = ENV['OPENAI_PROJECT_ID']    # Usage tracking
end
```

These headers are optional and only needed for organization-specific billing or project tracking.

## Azure Deployments

Pass your Azure deployment name as `model:`. It can differ from the underlying model's name. Listing a model in the catalog does not mean your resource has a deployment for it.

Set `azure_api_base` to your resource URL, deployment URL, or `/openai/v1` base. Use a deployment that supports the operation you call.

For a custom Cohere embedding deployment name or a dedicated serverless endpoint, select the protocol in a context:

```ruby
cohere = RubyLLM.context do |config|
  config.azure_api_base = ENV.fetch("AZURE_COHERE_ENDPOINT")
  config.azure_api_key = ENV.fetch("AZURE_COHERE_API_KEY")
  config.azure_protocol = :cohere
end

embedding = cohere.embed(
  "Ruby frameworks",
  model: ENV.fetch("AZURE_COHERE_DEPLOYMENT"),
  provider: :azure,
  task_type: "search_query"
)
```

Use the endpoint and key belonging to that deployment. For image-only Embed v3 requests, use the registered model name as the deployment name; custom names use the Embed v4 media format. See [Embeddings]({% link _core_features/embeddings.md %}) for text and image inputs.

## Vertex AI Authentication Configuration

RubyLLM supports both Vertex AI authentication methods:

- Application Default Credentials (ADC)
- Service Account JSON key via `config.vertexai_service_account_key`

If `vertexai_service_account_key` is not set, RubyLLM uses ADC.

### Reranking

Enable the Discovery Engine API in your Google Cloud project and grant your credentials access to rank documents. RubyLLM uses the project's global `default_ranking_config`. Set `vertexai_ranking_config` to a full resource name if you need a different configuration, or `vertexai_ranking_api_base` for a custom endpoint. See [Reranking]({% link _core_features/rerank.md %}) for examples.

## Batch Processing

Some providers need an additional gem or storage location for [batches]({% link _advanced/batches.md %}). Add the gem for the provider you use to your Gemfile:

| Provider | Gem | Configuration |
| --- | --- | --- |
| Cohere | `avro` | Required to read batch results. |
| Bedrock | `aws-sdk-s3` | Set `bedrock_batch_s3_uri` to an S3 prefix and `bedrock_batch_role_arn` to the role Bedrock assumes. |
| Vertex AI | `google-cloud-storage` | Set `vertexai_batch_gcs_uri` to a Cloud Storage prefix. |

For Bedrock, your credentials need permission to submit jobs, pass the role, and read and write the S3 prefix. The role must trust Bedrock and have access to the input and output objects. For Vertex AI, give your credentials access to submit batch jobs and read and write the Cloud Storage prefix; the service account running the job also needs access to those objects.

## GPUStack Deployments

Configure `gpustack_api_base` and `gpustack_api_key` for your GPUStack installation. The available operations depend on its deployed models and backends.

For [tokenization]({% link _core_features/tokenization.md %}#tokenizing-text) or [video generation]({% link _core_features/video-generation.md %}), enable the model proxy and set `gpustack_api_base` to its `/model/proxy/ROUTE_ID/v1` URL, including any installation path prefix. The route ID identifies the deployment; pass its model name separately as `model:`. These operations require a vLLM tokenizer or vLLM-Omni video model respectively. The standard `/v1` gateway does not expose them.

For [server tools]({% link _core_features/server-tools.md %}), configure MCP servers on the vLLM deployment. Web search and web fetch use the `web_search_preview` label; code execution uses `code_interpreter`. The backend controls which tools are available and permitted.

## Media Generation

Most media calls use your provider's existing configuration. These services require additional setup:

| Service | Setup |
| --- | --- |
| Bedrock video | Set `bedrock_video_s3_uri` to an output prefix in the same region as the model. Allow Bedrock to write there. Add `aws-sdk-s3` to your Gemfile and give your credentials permission to list and read the output. |
| Vertex AI video | Set `vertexai_location` to a region that serves your Veo model. For Cloud Storage output, add `google-cloud-storage` to your Gemfile and give your credentials read access to the output bucket. |
| ElevenLabs Image & Video | Use a Pro plan or above and a key with Image & Video or Flows permission. The same `elevenlabs_api_key` serves audio, images, and video. Its model-listing endpoint omits media models, so pass a documented model with `assume_model_exists: true` and `provider: :elevenlabs`. |

See [Image Generation]({% link _core_features/image-generation.md %}) and [Video Generation]({% link _core_features/video-generation.md %}) for inputs, output formats, and job handling.

## Custom Endpoints

### OpenAI-Compatible APIs

Connect to any OpenAI-compatible API endpoint, including local models, proxies, and custom servers:

```ruby
RubyLLM.configure do |config|
  # API key - use what your server expects
  config.openai_api_key = ENV['CUSTOM_API_KEY']  # Or 'dummy-key' if not required

  config.openai_api_base = "http://localhost:8080/v1"  # vLLM, LiteLLM, etc.
end

chat = RubyLLM.chat(model: ENV.fetch("CUSTOM_CHAT_MODEL"), provider: :openai, assume_model_exists: true)
```

#### System Role Compatibility

OpenAI's API now uses 'developer' role for system messages, but some OpenAI-compatible servers still require the traditional 'system' role:

```ruby
RubyLLM.configure do |config|
  # For servers that require 'system' role (e.g., older vLLM, some local models)
  config.openai_use_system_role = true  # Use 'system' role instead of 'developer'

  config.openai_api_base = "http://localhost:11434/v1"  # Ollama, vLLM, etc.
  config.openai_api_key = "dummy-key"  # If required by your server
end
```

### Gemini API Versions

Gemini offers two API versions: `v1` (stable) and `v1beta` (early access). RubyLLM defaults to `v1beta` for access to the latest features, but you can switch to `v1` to support older models:

```ruby
RubyLLM.configure do |config|
  config.gemini_api_key = ENV['GEMINI_API_KEY']
  config.gemini_api_base = 'https://generativelanguage.googleapis.com/v1'
end
```

Some older models are only available on specific API versions. Check the [Gemini API documentation](https://ai.google.dev/gemini-api/docs/api-versions) for version-specific model availability.

### Provider-Specific API Base URLs

Every provider exposes a provider-specific `*_api_base` setting. Use these when routing a native provider API through a proxy, gateway, private network endpoint, or compatible service:

```ruby
RubyLLM.configure do |config|
  config.perplexity_api_base = ENV['PERPLEXITY_API_BASE']
  config.mistral_api_base = ENV['MISTRAL_API_BASE']
  config.xai_api_base = ENV['XAI_API_BASE']
  config.bedrock_api_base = ENV['BEDROCK_API_BASE']
  config.vertexai_api_base = ENV['VERTEXAI_API_BASE']
end
```

Blank strings are treated as unset, so environment variables can be wired directly without causing invalid URL errors.

## Next Steps

- [Custom Endpoints and Unlisted Models]({% link _reference/custom-endpoints.md %}) - work with models RubyLLM doesn't know about.
- [Connection, Logging and Contexts]({% link _getting_started/configuration-connection.md %}) - timeouts, proxies, and per-tenant isolation.
- [Configuration]({% link _getting_started/configuration.md %}#full-reference) - the complete option list.
- [Model Registry]({% link _reference/models.md %}) - discover, select, and refresh the model registry.

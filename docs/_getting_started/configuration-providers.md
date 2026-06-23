---
layout: default
title: Provider Setup and Custom Endpoints
parent: Configuration
nav_order: 1
description: Per-provider API keys, organization headers, Bedrock and Vertex AI authentication, and OpenAI-compatible custom endpoints.
---

# {{ page.title }}
{: .no_toc }

{{ page.description }}
{: .fs-6 .fw-300 }

## Table of contents
{: .no_toc .text-delta }

1. TOC
{:toc}

---

After reading this guide, you will know:

* How to configure API keys for every supported provider.
* How to set OpenAI organization and project headers.
* How to authenticate with Bedrock credential providers and Vertex AI service accounts.
* How to connect to OpenAI-compatible and custom endpoints.

## API Keys

Configure API keys only for the providers you use. RubyLLM won't complain about missing keys for providers you never touch.

```ruby
RubyLLM.configure do |config|
  # Anthropic
  config.anthropic_api_key = ENV['ANTHROPIC_API_KEY']
  config.anthropic_api_base = ENV['ANTHROPIC_API_BASE'] # Available in v1.13.0+ (optional custom Anthropic endpoint)

  # Azure
  config.azure_api_base = ENV['AZURE_API_BASE'] # Microsoft Foundry project endpoint
  config.azure_api_key = ENV['AZURE_API_KEY'] # use this or
  config.azure_ai_auth_token = ENV['AZURE_AI_AUTH_TOKEN'] # this

  # Bedrock
  config.bedrock_api_key = ENV['AWS_ACCESS_KEY_ID']
  config.bedrock_secret_key = ENV['AWS_SECRET_ACCESS_KEY']
  config.bedrock_region = ENV['AWS_REGION'] # Required for Bedrock
  config.bedrock_session_token = ENV['AWS_SESSION_TOKEN'] # For temporary credentials
  # config.bedrock_credential_provider = Aws::InstanceProfileCredentials.new # Optional Aws::CredentialProvider
  config.bedrock_api_base = ENV['BEDROCK_API_BASE'] # v1.16+ (optional custom Bedrock endpoint)

  # DeepSeek
  config.deepseek_api_key = ENV['DEEPSEEK_API_KEY']
  config.deepseek_api_base = ENV['DEEPSEEK_API_BASE'] # Available in v1.13.0+ (optional custom DeepSeek endpoint)

  # Gemini
  config.gemini_api_key = ENV['GEMINI_API_KEY']
  config.gemini_api_base = ENV['GEMINI_API_BASE'] # Available in v1.9.0+ (optional API version override)

  # GPUStack
  config.gpustack_api_base = ENV['GPUSTACK_API_BASE']
  config.gpustack_api_key = ENV['GPUSTACK_API_KEY']

  # Mistral
  config.mistral_api_key = ENV['MISTRAL_API_KEY']
  config.mistral_api_base = ENV['MISTRAL_API_BASE'] # v1.16+ (optional custom Mistral endpoint)

  # Ollama
  config.ollama_api_base = 'http://localhost:11434/v1'
  config.ollama_api_key = ENV['OLLAMA_API_KEY'] # Available in v1.13.0+ (optional for authenticated/remote Ollama endpoints)

  # OpenAI
  config.openai_api_key = ENV['OPENAI_API_KEY']
  config.openai_api_base = ENV['OPENAI_API_BASE'] # Optional custom OpenAI-compatible endpoint

  # OpenRouter
  config.openrouter_api_key = ENV['OPENROUTER_API_KEY']
  config.openrouter_api_base = ENV['OPENROUTER_API_BASE'] # Available in v1.13.0+ (optional custom OpenRouter endpoint)

  # Perplexity
  config.perplexity_api_key = ENV['PERPLEXITY_API_KEY']
  config.perplexity_api_base = ENV['PERPLEXITY_API_BASE'] # v1.16+ (optional custom Perplexity endpoint)

  # Vertex AI
  config.vertexai_project_id = ENV['GOOGLE_CLOUD_PROJECT'] # Available in v1.7.0+
  config.vertexai_location = ENV['GOOGLE_CLOUD_LOCATION']
  config.vertexai_service_account_key = ENV['VERTEXAI_SERVICE_ACCOUNT_KEY'] # Optional: service account JSON key
  config.vertexai_api_base = ENV['VERTEXAI_API_BASE'] # v1.16+ (optional custom Vertex AI endpoint)

  # xAI
  config.xai_api_key = ENV['XAI_API_KEY'] # Available in v1.11.0+
  config.xai_api_base = ENV['XAI_API_BASE'] # v1.16+ (optional custom xAI endpoint)
end
```

> Attempting to use an unconfigured provider will raise `RubyLLM::ConfigurationError`. Only configure what you need.
{: .note }

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

## Vertex AI Authentication Configuration

RubyLLM supports both Vertex AI authentication methods:

- Application Default Credentials (ADC)
- Service Account JSON key via `config.vertexai_service_account_key`

If `vertexai_service_account_key` is not set, RubyLLM uses ADC.

## Custom Endpoints

### OpenAI-Compatible APIs

Connect to any OpenAI-compatible API endpoint, including local models, proxies, and custom servers:

```ruby
RubyLLM.configure do |config|
  # API key - use what your server expects
  config.openai_api_key = ENV['CUSTOM_API_KEY']  # Or 'dummy-key' if not required

  config.openai_api_base = "http://localhost:8080/v1"  # vLLM, LiteLLM, etc.
end

chat = RubyLLM.chat(model: 'my-custom-model', provider: :openai, assume_model_exists: true)
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

By default, RubyLLM uses the 'developer' role (matching OpenAI's current API). Set `openai_use_system_role` to true for compatibility with servers that still expect 'system'.

### Gemini API Versions

Gemini offers two API versions: `v1` (stable) and `v1beta` (early access). RubyLLM defaults to `v1beta` for access to the latest features, but you can switch to `v1` to support older models:

```ruby
RubyLLM.configure do |config|
  config.gemini_api_key = ENV['GEMINI_API_KEY']
  config.gemini_api_base = 'https://generativelanguage.googleapis.com/v1'
end
```

Some models are only available on specific API versions. For example, `gemini-1.5-flash-8b` requires `v1`. Check the [Gemini API documentation](https://ai.google.dev/gemini-api/docs/api-versions) for version-specific model availability.

### Provider-Specific API Base URLs

Every provider exposes a provider-specific `*_api_base` setting in v1.16+. Use these when routing a native provider API through a proxy, gateway, private network endpoint, or compatible service:

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
- [Configuration Reference]({% link _getting_started/configuration-reference.md %}) - the complete option list.
- [Working with Models]({% link _reference/models.md %}) - discover, select, and refresh the model registry.

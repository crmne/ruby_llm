---
layout: default
title: Configuration Reference
parent: Configuration
nav_order: 3
description: The complete list of every RubyLLM configuration option in one block.
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

* Every configuration option RubyLLM exposes and its type.
* Which version introduced each newer option.
* Where to look up the detailed behavior of a given setting.

## Configuration Reference

Here's a complete reference of all configuration options:

```ruby
RubyLLM.configure do |config|
  # Anthropic
  config.anthropic_api_key = String
  config.anthropic_api_base = String  # v1.13.0+

  # Azure
  config.azure_api_base = String  # v1.12.0+
  config.azure_api_key = String  # v1.12.0+
  config.azure_ai_auth_token = String  # v1.12.0+

  # Bedrock
  config.bedrock_api_key = String
  config.bedrock_secret_key = String
  config.bedrock_region = String
  config.bedrock_session_token = String
  config.bedrock_credential_provider = Object # Aws::CredentialProvider
  config.bedrock_api_base = String  # v1.16+

  # DeepSeek
  config.deepseek_api_key = String
  config.deepseek_api_base = String  # v1.13.0+

  # Gemini
  config.gemini_api_key = String
  config.gemini_api_base = String  # v1.9.0+

  # GPUStack
  config.gpustack_api_base = String
  config.gpustack_api_key = String

  # Mistral
  config.mistral_api_key = String
  config.mistral_api_base = String  # v1.16+

  # Ollama
  config.ollama_api_base = String
  config.ollama_api_key = String  # v1.13.0+

  # OpenAI
  config.openai_api_key = String
  config.openai_api_base = String
  config.openai_organization_id = String
  config.openai_project_id = String
  config.openai_use_system_role = Boolean

  # OpenRouter
  config.openrouter_api_key = String
  config.openrouter_api_base = String  # v1.13.0+

  # Perplexity
  config.perplexity_api_key = String
  config.perplexity_api_base = String  # v1.16+

  # Vertex AI
  config.vertexai_project_id = String  # GCP project ID
  config.vertexai_location = String     # e.g., 'us-central1'
  config.vertexai_service_account_key = String # Optional: service account JSON key (ADC used when unset)
  config.vertexai_api_base = String  # v1.16+

  # xAI
  config.xai_api_key = String
  config.xai_api_base = String  # v1.16+

  # Default Models
  config.default_model = String
  config.default_embedding_model = String
  config.default_image_model = String
  config.default_moderation_model = String
  config.default_transcription_model = String

  # Model Registry
  config.model_registry_file = String  # Path to model registry JSON file (v1.9.0+)
  config.model_registry_class = String

  # Connection Settings
  config.request_timeout = Integer
  config.max_retries = Integer
  config.retry_interval = Float
  config.retry_backoff_factor = Integer
  config.retry_interval_randomness = Float
  config.http_proxy = String
  config.faraday_adapter = Symbol # Defaults to :net_http

  # Logging
  config.logger = Logger
  config.instrumenter = Object # Responds to instrument(name, payload) { ... }
  config.deprecation_behavior = :warn # :warn, :silence, or :raise
  config.log_file = String
  config.log_level = Symbol
  config.log_stream_debug = Boolean
  config.log_regexp_timeout = Numeric  # v1.13.0+ (Ruby 3.2+ support)
end
```

## Next Steps

- [Provider Setup and Custom Endpoints]({% link _getting_started/configuration-providers.md %}) - what each provider key, base URL, and header does.
- [Connection, Logging and Contexts]({% link _getting_started/configuration-connection.md %}) - how timeout, retry, logging, and registry options behave.
- [Configuration]({% link _getting_started/configuration.md %}) - back to the overview and Quick Start.

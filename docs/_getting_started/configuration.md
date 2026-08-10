---
layout: default
title: Configuration
nav_order: 3
has_children: true
description: Configure once, use everywhere. API keys, defaults, timeouts, and multi-tenant contexts made simple.
redirect_from:
  - /configuration-reference/
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

* How to configure API keys for the providers you use.
* How to set default models for chat, embeddings, and images.
* How to wire RubyLLM into a Rails initializer.
* Where to find provider, connection, and reference details.

## Quick Start

The simplest configuration just sets your API keys:

```ruby
RubyLLM.configure do |config|
  config.openai_api_key = ENV['OPENAI_API_KEY']
  config.anthropic_api_key = ENV['ANTHROPIC_API_KEY']
end
```

That's it. RubyLLM uses sensible defaults for everything else.

## API Keys

Configure API keys only for the providers you use. RubyLLM won't complain about missing keys for providers you never touch.

```ruby
RubyLLM.configure do |config|
  config.openai_api_key = ENV['OPENAI_API_KEY']
  config.anthropic_api_key = ENV['ANTHROPIC_API_KEY']
  config.gemini_api_key = ENV['GEMINI_API_KEY']
end
```

Each provider has its own key (and sometimes region or project settings). For the full list of providers, organization headers, Vertex AI authentication, and OpenAI-compatible custom endpoints, see [Provider Setup and Custom Endpoints]({% link _getting_started/configuration-providers.md %}).

> Attempting to use an unconfigured provider will raise `RubyLLM::ConfigurationError`. Only configure what you need.
{: .note }

## Default Models

Set defaults for the convenience methods (`RubyLLM.chat`, `RubyLLM.embed`, `RubyLLM.paint`):

```ruby
RubyLLM.configure do |config|
  config.default_model = '{{ site.models.anthropic_current }}'           # For RubyLLM.chat
  config.default_embedding_model = '{{ site.models.embedding_large }}'  # For RubyLLM.embed
  config.default_image_model = 'dall-e-3'              # For RubyLLM.paint
  config.default_speech_model = '{{ site.models.default_speech }}'       # For RubyLLM.speak
end
```

Defaults if not configured:
- Chat: `{{ site.models.default_chat }}`
- Embeddings: `{{ site.models.default_embedding }}`
- Images: `{{ site.models.default_image }}`
- Speech: `{{ site.models.default_speech }}`

## Rails Integration

For Rails applications, create an initializer:

```ruby
# config/initializers/ruby_llm.rb
RubyLLM.configure do |config|
  config.openai_api_key = Rails.application.credentials.openai_api_key
  config.anthropic_api_key = Rails.application.credentials.anthropic_api_key
  config.anthropic_api_base = ENV['ANTHROPIC_API_BASE'] # Available in v1.13.0+ (optional custom Anthropic endpoint)
  config.ollama_api_key = ENV['OLLAMA_API_KEY'] # Available in v1.13.0+ (optional for remote/authenticated Ollama)

  config.logger = Rails.logger

  config.request_timeout = Rails.env.production? ? 120 : 30
  config.log_level = Rails.env.production? ? :info : :debug
end
```

## Full Reference

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
  config.openrouter_app_url = String   # App attribution URL sent as HTTP-Referer
  config.openrouter_app_name = String  # App attribution name sent as X-OpenRouter-Title

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
  config.default_speech_model = String
  config.default_moderation_model = String
  config.default_transcription_model = String

  # Model Registry
  config.model_registry_file = String  # Writable registry cache; defaults to the OS user cache directory

  # Connection Settings
  config.request_timeout = Integer
  config.max_retries = Integer
  config.retry_interval = Float
  config.retry_backoff_factor = Integer
  config.retry_interval_randomness = Float
  config.http_proxy = String
  config.faraday_adapter = Symbol # Defaults to :net_http
  config.auto_upload_large_files = Boolean

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

- [Provider Setup and Custom Endpoints]({% link _getting_started/configuration-providers.md %}) - every provider's keys, OpenAI organization headers, Vertex AI auth, and OpenAI-compatible endpoints.
- [Connection, Logging and Contexts]({% link _getting_started/configuration-connection.md %}) - timeouts, retries, proxies, debug logging, the model registry file, and isolated per-tenant contexts.
- [Start chatting with AI models]({% link _core_features/chat.md %}) - put your configuration to work.
- [Set up Rails integration]({% link _advanced/rails.md %}) - persistence, streaming, and generators.

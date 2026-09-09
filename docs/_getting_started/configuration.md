---
layout: default
title: Configuration
nav_order: 3
has_children: true
description: Set provider credentials, choose default models, and share configuration across the RubyLLM API.
redirect_from:
  - /configuration-reference/
---

# {{ page.title }}

{{ page.description }}
{: .fs-6 .fw-300 }

After reading this guide, you will know:

* How to configure API keys for the providers you use.
* How to set default models for conversations, media, and document processing.
* How to wire RubyLLM into a Rails initializer.
* Where to find provider, connection, and reference details.

## Quick Start

Configure a provider to start using its models:

```ruby
RubyLLM.configure do |config|
  config.openai_api_key = ENV.fetch('OPENAI_API_KEY')
end
```

RubyLLM uses its defaults for models, timeouts, and retries. Set only what your application needs.

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

Set defaults for the operations you use:

```ruby
RubyLLM.configure do |config|
  config.default_model = '{{ site.models.anthropic_current }}'           # For RubyLLM.chat
  config.default_embedding_model = '{{ site.models.embedding_large }}'  # For RubyLLM.embed
  config.default_image_model = '{{ site.models.default_image }}'        # For RubyLLM.paint
  config.default_video_model = '{{ site.models.default_video }}'        # For RubyLLM.animate
  config.default_speech_model = '{{ site.models.default_speech }}'       # For RubyLLM.speak
  config.default_transcription_model = '{{ site.models.default_transcription }}' # For RubyLLM.transcribe
  config.default_ocr_model = '{{ site.models.default_ocr }}'              # For RubyLLM.ocr
  config.default_moderation_model = '{{ site.models.default_moderation }}' # For RubyLLM.moderate
end
```

Defaults if not configured:
- Chat: `gpt-5.6`
- Embeddings: `{{ site.models.default_embedding }}`
- Images: `{{ site.models.default_image }}`
- Videos: `grok-imagine-video-1.5`
- Speech: `{{ site.models.default_speech }}`
- Moderation: `omni-moderation-latest`
- Transcription: `gpt-transcribe`
- OCR: `mistral-ocr-latest`

`rerank` requires `model:` on each call; it has no default model setting.

## Rails Integration

Put the same configuration in `config/initializers/ruby_llm.rb`. For example, with Rails credentials:

```ruby
RubyLLM.configure do |config|
  config.openai_api_key = Rails.application.credentials.openai_api_key
  config.logger = Rails.logger
end
```

See [Rails Integration]({% link _advanced/rails.md %}) for persistence, Active Storage attachments, streaming, and jobs.

## Full Reference

Here's a complete reference of all configuration options:

```ruby
RubyLLM.configure do |config|
  # Anthropic
  config.anthropic_api_key = String
  config.anthropic_api_base = String

  # Azure
  config.azure_api_base = String
  config.azure_api_key = String
  config.azure_ai_auth_token = String

  # Bedrock
  config.bedrock_api_key = String
  config.bedrock_secret_key = String
  config.bedrock_region = String
  config.bedrock_session_token = String
  config.bedrock_credential_provider = Object # Aws::CredentialProvider
  config.bedrock_api_base = String
  config.bedrock_mantle_api_base = String
  config.bedrock_batch_s3_uri = String   # s3://bucket/prefix for batches and large attachments
  config.bedrock_batch_role_arn = String # IAM role Bedrock assumes to run batch jobs
  config.bedrock_video_s3_uri = String # s3://bucket/prefix for generated videos
  config.bedrock_guardrail_id = String
  config.bedrock_guardrail_version = String

  # Cohere
  config.cohere_api_key = String
  config.cohere_api_base = String

  # Deepgram
  config.deepgram_api_key = String
  config.deepgram_api_base = String

  # DeepSeek
  config.deepseek_api_key = String
  config.deepseek_api_base = String

  # ElevenLabs
  config.elevenlabs_api_key = String
  config.elevenlabs_api_base = String

  # Gemini
  config.gemini_api_key = String
  config.gemini_api_base = String

  # GPUStack
  config.gpustack_api_base = String
  config.gpustack_api_key = String

  # Mistral
  config.mistral_api_key = String
  config.mistral_api_base = String

  # Ollama
  config.ollama_api_base = String
  config.ollama_api_key = String

  # Ollama Cloud
  config.ollama_cloud_api_key = String
  config.ollama_cloud_api_base = String

  # OpenAI
  config.openai_api_key = String
  config.openai_api_base = String
  config.openai_organization_id = String
  config.openai_project_id = String
  config.openai_use_system_role = Boolean
  config.openai_protocol = Symbol # Every provider exposes <provider>_protocol

  # OpenRouter
  config.openrouter_api_key = String
  config.openrouter_api_base = String
  config.openrouter_app_url = String   # App attribution URL sent as HTTP-Referer
  config.openrouter_app_name = String  # App attribution name sent as X-OpenRouter-Title

  # Perplexity
  config.perplexity_api_key = String
  config.perplexity_api_base = String

  # Vertex AI
  config.vertexai_project_id = String  # GCP project ID
  config.vertexai_location = String     # e.g., 'us-central1'
  config.vertexai_service_account_key = String # Optional: service account JSON key (ADC used when unset)
  config.vertexai_api_base = String
  config.vertexai_batch_gcs_uri = String # gs://bucket/prefix for batches and large attachments
  config.vertexai_ranking_api_base = String # Optional Discovery Engine endpoint
  config.vertexai_ranking_config = String # Optional full rankingConfig resource name

  # xAI
  config.xai_api_key = String
  config.xai_api_base = String

  # Default Models
  config.default_model = String
  config.default_embedding_model = String
  config.default_image_model = String
  config.default_video_model = String
  config.default_speech_model = String
  config.default_moderation_model = String
  config.default_transcription_model = String
  config.default_ocr_model = String

  # Model Registry
  config.model_registry_file = String  # Writable registry cache; defaults to the OS user cache directory
  config.model_registry_store = Object # Responds to read, optionally write(registry)

  # Connection Settings
  config.request_timeout = Integer
  config.video_generation_timeout = Integer
  config.video_generation_poll_interval = Integer
  config.max_retries = Integer
  config.retry_interval = Float
  config.retry_backoff_factor = Integer
  config.retry_interval_randomness = Float
  config.retry_max_interval = Integer
  config.http_proxy = String
  config.faraday_adapter = Symbol # Defaults to :net_http
  config.auto_upload_large_files = Boolean
  config.tool_concurrency = false # true/:threads or :fibers

  # Logging
  config.logger = Logger
  config.instrumenter = Object # Responds to instrument(name, payload) { ... }
  config.deprecation_behavior = :warn # :warn, :silence, or :raise
  config.log_file = String
  config.log_level = Symbol
  config.log_stream_debug = Boolean
  config.log_regexp_timeout = Numeric  # Ruby 3.2+ support
end
```

## Next Steps

- [Provider Setup and Custom Endpoints]({% link _getting_started/configuration-providers.md %}) - every provider's keys, OpenAI organization headers, Vertex AI auth, and OpenAI-compatible endpoints.
- [Connection, Logging and Contexts]({% link _getting_started/configuration-connection.md %}) - timeouts, retries, proxies, debug logging, the model registry file, and isolated per-tenant contexts.
- [Start chatting with AI models]({% link _core_features/chat.md %}) - put your configuration to work.
- [Set up Rails integration]({% link _advanced/rails.md %}) - persistence, streaming, and generators.

---
layout: default
title: Configuration
nav_order: 3
description: Configure once, use everywhere. API keys, defaults, timeouts, and multi-tenant contexts made simple.
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

* How to configure API keys for different providers
* How to set default models for chat, embeddings, and images
* How to customize connection settings and timeouts
* How to use custom endpoints and proxies
* How to create isolated configurations with contexts
* How to configure logging and debugging

## Quick Start

The simplest configuration just sets your API keys:

```ruby
RubyLLM.configure do |config|
  config.openai_api_key = ENV['OPENAI_API_KEY']
  config.anthropic_api_key = ENV['ANTHROPIC_API_KEY']
end
```

That's it. RubyLLM uses sensible defaults for everything else.

## Provider Configuration

### API Keys

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

  # Vertex AI
  config.vertexai_project_id = ENV['GOOGLE_CLOUD_PROJECT'] # Available in v1.7.0+
  config.vertexai_location = ENV['GOOGLE_CLOUD_LOCATION']
  config.vertexai_service_account_key = ENV['VERTEXAI_SERVICE_ACCOUNT_KEY'] # Optional: service account JSON key

  # xAI
  config.xai_api_key = ENV['XAI_API_KEY'] # Available in v1.11.0+
end
```

> Attempting to use an unconfigured provider will raise `RubyLLM::ConfigurationError`. Only configure what you need.
{: .note }

### OpenAI Organization & Project Headers

For OpenAI users with multiple organizations or projects:

```ruby
RubyLLM.configure do |config|
  config.openai_api_key = ENV['OPENAI_API_KEY']
  config.openai_organization_id = ENV['OPENAI_ORG_ID']  # Billing organization
  config.openai_project_id = ENV['OPENAI_PROJECT_ID']    # Usage tracking
end
```

These headers are optional and only needed for organization-specific billing or project tracking.

### Vertex AI Authentication Configuration

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

  # Your custom endpoint
  config.openai_api_base = "http://localhost:8080/v1"  # vLLM, LiteLLM, etc.
end

# Use your custom model name
chat = RubyLLM.chat(model: 'my-custom-model', provider: :openai, assume_model_exists: true)
```

#### System Role Compatibility

OpenAI's API now uses 'developer' role for system messages, but some OpenAI-compatible servers still require the traditional 'system' role:

```ruby
RubyLLM.configure do |config|
  # For servers that require 'system' role (e.g., older vLLM, some local models)
  config.openai_use_system_role = true  # Use 'system' role instead of 'developer'

  # Your OpenAI-compatible endpoint
  config.openai_api_base = "http://localhost:11434/v1"  # Ollama, vLLM, etc.
  config.openai_api_key = "dummy-key"  # If required by your server
end
```

By default, RubyLLM uses the 'developer' role (matching OpenAI's current API). Set `openai_use_system_role` to true for compatibility with servers that still expect 'system'.

### Gemini API Versions
{: .d-inline-block }

v1.9.0+
{: .label .label-green }

Gemini offers two API versions: `v1` (stable) and `v1beta` (early access). RubyLLM defaults to `v1beta` for access to the latest features, but you can switch to `v1` to support older models:

```ruby
RubyLLM.configure do |config|
  config.gemini_api_key = ENV['GEMINI_API_KEY']
  config.gemini_api_base = 'https://generativelanguage.googleapis.com/v1'
end
```

Some models are only available on specific API versions. For example, `gemini-1.5-flash-8b` requires `v1`. Check the [Gemini API documentation](https://ai.google.dev/gemini-api/docs/api-versions) for version-specific model availability.

## Default Models

Set defaults for the convenience methods (`RubyLLM.chat`, `RubyLLM.embed`, `RubyLLM.paint`):

```ruby
RubyLLM.configure do |config|
  config.default_model = '{{ site.models.anthropic_current }}'           # For RubyLLM.chat
  config.default_embedding_model = '{{ site.models.embedding_large }}'  # For RubyLLM.embed
  config.default_image_model = 'dall-e-3'              # For RubyLLM.paint
end
```

Defaults if not configured:
- Chat: `{{ site.models.default_chat }}`
- Embeddings: `{{ site.models.default_embedding }}`
- Images: `{{ site.models.default_image }}`

## Default Providers

Route models to specific providers by default, so you don't have to pass `provider:` on every call:

```ruby
RubyLLM.configure do |config|
  config.default_providers = {
    'claude' => :bedrock,            # all claude models route to bedrock
    'claude-haiku' => :anthropic,    # except haiku, which goes direct to anthropic
    'gpt' => :azure,                 # all gpt models route to azure
    'gemini' => :vertexai,           # all gemini models route to vertex ai
    'claude-sonnet-4-5' => :openrouter,  # one specific model via openrouter
  }
end
```

Keys are matched against the start of the model ID. When multiple keys match, the longest (most specific) one wins. Passing an explicit `provider:` argument always overrides `default_providers`.

This applies to all model types: chat, embeddings, images, transcription, and moderation.

## Model Registry File

By default, RubyLLM reads model information from the bundled `models.json` file. If your gem directory is read-only, you can configure a writable location:

```ruby
# First time: save to writable location
RubyLLM.models.save_to_json('/var/app/models.json')

# Configure to use new location (Available in v1.9.0+)
RubyLLM.configure do |config|
  config.model_registry_file = '/var/app/models.json'
end
```

After this one-time setup, RubyLLM will read from your configured path automatically.

> `RubyLLM.models.refresh!` updates the in-memory registry only. To persist changes, call `RubyLLM.models.save_to_json`.
{: .note }

> If you're using the ActiveRecord integration, model data is stored in the database. This configuration doesn't apply.
{: .note }

## Connection Settings

### Timeouts & Retries

Fine-tune how RubyLLM handles network connections:

```ruby
RubyLLM.configure do |config|
  # Basic settings
  config.request_timeout = 120        # Seconds to wait for response (default: 300)
  config.max_retries = 3              # Retry attempts on failure (default: 3)

  # Advanced retry behavior
  config.retry_interval = 0.1         # Initial retry delay in seconds (default: 0.1)
  config.retry_backoff_factor = 2     # Exponential backoff multiplier (default: 2)
  config.retry_interval_randomness = 0.5  # Jitter to prevent thundering herd (default: 0.5)
end
```

Example for high-latency connections:

```ruby
RubyLLM.configure do |config|
  config.request_timeout = 300        # 5 minutes for complex tasks
  config.max_retries = 5              # More retry attempts
  config.retry_interval = 1.0         # Start with 1 second delay
  config.retry_backoff_factor = 1.5   # Less aggressive backoff
end
```

### HTTP Proxy Support

Route requests through a proxy:

```ruby
RubyLLM.configure do |config|
  # Basic proxy
  config.http_proxy = "http://proxy.company.com:8080"

  # Authenticated proxy
  config.http_proxy = "http://user:pass@proxy.company.com:8080"

  # SOCKS5 proxy
  config.http_proxy = "socks5://proxy.company.com:1080"
end
```

## Logging & Debugging

### Basic Logging

```ruby
RubyLLM.configure do |config|
  # Log to file
  config.log_file = '/var/log/ruby_llm.log'
  config.log_level = :info  # :debug, :info, :warn

  # Or use Rails logger
  config.logger = Rails.logger  # Overrides log_file and log_level
end
```

Log levels:
- `:debug` - Detailed request/response information
- `:info` - General operational information
- `:warn` - Non-critical issues

> Setting `config.logger` overrides `log_file` and `log_level` settings.
{: .note }

### Advanced Logging Options

Use these options when you need deeper troubleshooting or safer handling of large debug payloads.

```ruby
RubyLLM.configure do |config|
  # Enable verbose chunk-level stream debugging
  config.log_stream_debug = true

  # Available in v1.13.0+
  # Timeout (seconds) used for regex-based log filtering
  config.log_regexp_timeout = 1.5
end
```

`log_stream_debug` notes:
- Shows chunk-by-chunk streaming internals (accumulator state, parsing, tool chunks)
- Useful for diagnosing streaming/provider parsing issues
- Can also be enabled with `RUBYLLM_STREAM_DEBUG=true`

`log_regexp_timeout` notes:
- Available in `v1.13.0+`
- Applies to regex filters used in request/response debug logging
- Supported on Ruby `3.2+` (uses `Regexp.timeout`)
- On Ruby `<3.2`, RubyLLM warns if set and continues without timeout
- Helps bound regex execution time when debug logs contain very large payloads

Built-in debug log redaction:
- Large base64-like blobs are redacted as `[BASE64 DATA]`
- Large embedding arrays are redacted as `[EMBEDDINGS ARRAY]`

### Debug Options

```ruby
RubyLLM.configure do |config|
  # Enable debug logging via environment variable
  config.log_level = :debug if ENV['RUBYLLM_DEBUG'] == 'true'

  # Show detailed streaming chunks
  config.log_stream_debug = true  # Or set RUBYLLM_STREAM_DEBUG=true
end
```

Stream debug logging shows every chunk, accumulator state, and parsing decision - invaluable for debugging streaming issues.

## Contexts: Isolated Configurations

Create temporary configuration scopes without affecting global settings. Perfect for multi-tenancy, testing, or specific task requirements.

### Basic Context Usage

```ruby
# Global config uses production OpenAI
RubyLLM.configure do |config|
  config.openai_api_key = ENV['OPENAI_PROD_KEY']
end

# Create isolated context
ctx = RubyLLM.context do |config|
  config.openai_api_key = ENV['ANOTHER_PROVIDER_KEY']
  config.openai_api_base = "https://another-provider.com"
  config.request_timeout = 180
end

# Use Azure for this specific task
ctx_chat = ctx.chat(model: '{{ site.models.openai_standard }}')
response = ctx_chat.ask("Process this with another provider...")

# Global config unchanged
regular_chat = RubyLLM.chat  # Still uses production OpenAI
```

### Multi-Tenant Applications

```ruby
class TenantService
  def initialize(tenant)
    @context = RubyLLM.context do |config|
      config.openai_api_key = tenant.openai_key
      config.default_model = tenant.preferred_model
      config.request_timeout = tenant.timeout_seconds
    end
  end

  def chat
    @context.chat
  end
end

# Each tenant gets isolated configuration
tenant_a_service = TenantService.new(tenant_a)
tenant_b_service = TenantService.new(tenant_b)
```

### Key Context Behaviors

- **Inheritance**: Contexts start with a copy of global configuration
- **Isolation**: Changes don't affect global `RubyLLM.config`
- **Thread Safety**: Each context is independent and thread-safe

## Rails Integration

For Rails applications, create an initializer:

```ruby
# config/initializers/ruby_llm.rb
RubyLLM.configure do |config|
  # Use Rails credentials
  config.openai_api_key = Rails.application.credentials.openai_api_key
  config.anthropic_api_key = Rails.application.credentials.anthropic_api_key
  config.anthropic_api_base = ENV['ANTHROPIC_API_BASE'] # Available in v1.13.0+ (optional custom Anthropic endpoint)
  config.ollama_api_key = ENV['OLLAMA_API_KEY'] # Available in v1.13.0+ (optional for remote/authenticated Ollama)

  # Use Rails logger
  config.logger = Rails.logger

  # Environment-specific settings
  config.request_timeout = Rails.env.production? ? 120 : 30
  config.log_level = Rails.env.production? ? :info : :debug
end
```

### Initializer Load Timing Issue with `use_new_acts_as`

**Important**: If you're using `use_new_acts_as = true` (from upgrading to 1.7+), you **cannot** set it in an initializer. Rails loads models before initializers run, so the legacy `acts_as` module will already be included by the time your initializer executes.

Instead, configure it in `config/application.rb` **before** the `Application` class:

```ruby
# config/application.rb
require_relative "boot"
require "rails/all"

# Configure RubyLLM before Rails::Application is inherited
RubyLLM.configure do |config|
  config.use_new_acts_as = true
end

module YourApp
  class Application < Rails::Application
    # ...
  end
end
```

This ensures RubyLLM is configured before ActiveRecord loads your models. Other configuration options (API keys, timeouts, etc.) can still go in your initializer.

> This limitation exists because both legacy and new `acts_as` APIs need to coexist during the 1.x series. It will be resolved in RubyLLM 2.0 when the legacy API is removed.
{: .note }

See the [Upgrading guide]({% link _advanced/upgrading.md %}#troubleshooting) for more details.

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

  # Vertex AI
  config.vertexai_project_id = String  # GCP project ID
  config.vertexai_location = String     # e.g., 'us-central1'
  config.vertexai_service_account_key = String # Optional: service account JSON key (ADC used when unset)

  # xAI
  config.xai_api_key = String

  # Default Models
  config.default_model = String
  config.default_embedding_model = String
  config.default_image_model = String
  config.default_moderation_model = String
  config.default_transcription_model = String

  # Default Providers
  config.default_providers = Hash  # Route models to providers by model ID prefix

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

  # Logging
  config.logger = Logger
  config.log_file = String
  config.log_level = Symbol
  config.log_stream_debug = Boolean
  config.log_regexp_timeout = Numeric  # v1.13.0+ (Ruby 3.2+ support)

  # Rails integration
  config.use_new_acts_as = Boolean
end
```

## Next Steps

Now that you've configured RubyLLM, you're ready to:

- [Start chatting with AI models]({% link _core_features/chat.md %})
- [Work with different providers and models]({% link _advanced/models.md %})
- [Set up Rails integration]({% link _advanced/rails.md %})

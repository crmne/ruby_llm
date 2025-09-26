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
  # Remote providers
  config.openai_api_key = ENV['OPENAI_API_KEY']
  config.anthropic_api_key = ENV['ANTHROPIC_API_KEY']
  config.gemini_api_key = ENV['GEMINI_API_KEY']
  config.vertexai_project_id = ENV['GOOGLE_CLOUD_PROJECT'] # Available in v1.7.0+
  config.vertexai_location = ENV['GOOGLE_CLOUD_LOCATION']
  config.deepseek_api_key = ENV['DEEPSEEK_API_KEY']
  config.mistral_api_key = ENV['MISTRAL_API_KEY']
  config.perplexity_api_key = ENV['PERPLEXITY_API_KEY']
  config.openrouter_api_key = ENV['OPENROUTER_API_KEY']

  # Local providers
  config.ollama_api_base = 'http://localhost:11434/v1'
  config.gpustack_api_base = ENV['GPUSTACK_API_BASE']
  config.gpustack_api_key = ENV['GPUSTACK_API_KEY']

  # AWS Bedrock (uses standard AWS credential chain if not set)
  config.bedrock_api_key = ENV['AWS_ACCESS_KEY_ID']
  config.bedrock_secret_key = ENV['AWS_SECRET_ACCESS_KEY']
  config.bedrock_region = ENV['AWS_REGION'] # Required for Bedrock
  config.bedrock_session_token = ENV['AWS_SESSION_TOKEN'] # For temporary credentials
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

## Connection Settings

### Timeouts & Retries

Fine-tune how RubyLLM handles network connections:

```ruby
RubyLLM.configure do |config|
  # Basic settings
  config.request_timeout = 120        # Seconds to wait for response (default: 120)
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

  # Set custom timeout for log filtering
  # which is useful when working with large payloads
  config.log_regexp_timeout = 4 # seconds
end
```

Log levels:
- `:debug` - Detailed request/response information
- `:info` - General operational information
- `:warn` - Non-critical issues

> Setting `config.logger` overrides `log_file` and `log_level` settings.
{: .note }

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

# Create isolated context for Azure
azure_context = RubyLLM.context do |config|
  config.openai_api_key = ENV['AZURE_KEY']
  config.openai_api_base = "https://azure.openai.azure.com"
  config.request_timeout = 180
end

# Use Azure for this specific task
azure_chat = azure_context.chat(model: '{{ site.models.openai_standard }}')
response = azure_chat.ask("Process this with Azure...")

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

  # Use Rails logger
  config.logger = Rails.logger

  # Environment-specific settings
  config.request_timeout = Rails.env.production? ? 120 : 30
  config.log_level = Rails.env.production? ? :info : :debug
end
```

## Configuration Reference

Here's a complete reference of all configuration options:

```ruby
RubyLLM.configure do |config|
  # Provider API Keys
  config.openai_api_key = String
  config.anthropic_api_key = String
  config.gemini_api_key = String
  config.vertexai_project_id = String  # GCP project ID
  config.vertexai_location = String     # e.g., 'us-central1'
  config.deepseek_api_key = String
  config.mistral_api_key = String
  config.perplexity_api_key = String
  config.openrouter_api_key = String
  config.gpustack_api_key = String

  # Provider Endpoints
  config.openai_api_base = String
  config.ollama_api_base = String
  config.gpustack_api_base = String

  # OpenAI Options
  config.openai_organization_id = String
  config.openai_project_id = String
  config.openai_use_system_role = Boolean

  # AWS Bedrock
  config.bedrock_api_key = String
  config.bedrock_secret_key = String
  config.bedrock_region = String
  config.bedrock_session_token = String

  # Default Models
  config.default_model = String
  config.default_embedding_model = String
  config.default_image_model = String

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
  config.log_regexp_timeout = Integer
end
```

## Next Steps

Now that you've configured RubyLLM, you're ready to:

- [Start chatting with AI models]({% link _core_features/chat.md %})
- [Work with different providers and models]({% link _advanced/models.md %})
- [Set up Rails integration]({% link _advanced/rails.md %})

---
layout: default
title: Connection, Logging and Contexts
parent: Configuration
nav_order: 2
description: Timeouts, retries, proxies, logging, the model registry file, and isolated multi-tenant contexts.
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

* Where RubyLLM reads the model registry and how to relocate it.
* How to tune timeouts, retries, and HTTP proxies.
* How to configure logging and debug streaming responses.
* How to create isolated configurations with contexts for multi-tenancy.

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

You can also enable debug logging conditionally from an environment variable:

```ruby
RubyLLM.configure do |config|
  config.log_level = :debug if ENV['RUBYLLM_DEBUG'] == 'true'
end
```

> Setting `config.logger` overrides `log_file` and `log_level` settings.
{: .note }

### Advanced Logging Options

Use these options when you need deeper troubleshooting or safer handling of large debug payloads.

```ruby
RubyLLM.configure do |config|
  config.log_stream_debug = true

  # Available in v1.13.0+
  config.log_regexp_timeout = 1.5
end
```

`log_stream_debug` notes:
- Shows chunk-by-chunk streaming internals (accumulator state, parsing, tool chunks)
- Invaluable for diagnosing streaming/provider parsing issues
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

## Contexts: Isolated Configurations

Create temporary configuration scopes without affecting global settings. Perfect for multi-tenancy, testing, or specific task requirements.

### Basic Context Usage

```ruby
# Global config uses production OpenAI
RubyLLM.configure do |config|
  config.openai_api_key = ENV['OPENAI_PROD_KEY']
end

ctx = RubyLLM.context do |config|
  config.openai_api_key = ENV['ANOTHER_PROVIDER_KEY']
  config.openai_api_base = "https://another-provider.com"
  config.request_timeout = 180
end

ctx_chat = ctx.chat(model: '{{ site.models.openai_standard }}')
response = ctx_chat.ask("Process this with another provider...")

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

## Next Steps

- [Configuration Reference]({% link _getting_started/configuration-reference.md %}) - the complete option list in one block.
- [Provider Setup and Custom Endpoints]({% link _getting_started/configuration-providers.md %}) - per-provider keys and OpenAI-compatible endpoints.
- [Instrumentation and Observability]({% link _advanced/instrumentation.md %}) - hook RubyLLM into your metrics and tracing stack.
- [Working with Models]({% link _reference/models.md %}) - discover, select, and refresh models.

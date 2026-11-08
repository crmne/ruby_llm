---
layout: default
title: Connection, Logging and Contexts
nav_order: 3
description: Timeouts, retries, proxies, connection reuse, logging, the model registry file, and isolated multi-tenant contexts.
---

# {{ page.title }}

{{ page.description }}
{: .fs-6 .fw-300 }

After reading this guide, you will know:

* Where RubyLLM reads the model registry and how to relocate it.
* How to tune timeouts, retries, and HTTP proxies.
* How to set TLS options for a server behind an internal certificate authority.
* How to reuse connections between calls with a keep-alive adapter.
* How to configure logging and debug streaming responses.
* How to create isolated configurations with contexts for multi-tenancy.

## Model Registry File

RubyLLM ships with a registry snapshot, so a new installation works without a network request. Plain Ruby applications use the registry in the operating system's user cache when one exists:

* Linux: `$XDG_CACHE_HOME/ruby_llm/models.json`, or `~/.cache/ruby_llm/models.json`
* macOS: `~/Library/Caches/RubyLLM/models.json`
* Windows: `%LOCALAPPDATA%\RubyLLM\Cache\models.json`

`RubyLLM.models.refresh` fetches the latest published catalog, merges models discovered from your configured providers, and atomically updates this cache. If the cache cannot be written, it raises `RubyLLM::ModelRegistryError` and leaves the in-memory registry unchanged.

Set `model_registry_file` only when your application needs a specific persistent location:

```ruby
RubyLLM.configure do |config|
  config.model_registry_file = "/var/app/models.json"
end

RubyLLM.models.refresh
```

RubyLLM falls back to its bundled snapshot until the configured file exists. The first successful refresh creates the file, and later refreshes replace it. Use `RubyLLM.models.save_to_json('/another/path/models.json')` only when you want to export the currently loaded registry elsewhere.

With the Active Record integration, RubyLLM's internal `ruby_llm_models` table is the registry. `RubyLLM.models.refresh` updates it automatically. While the table is empty, RubyLLM falls back to the registry file, then to the bundled snapshot.
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
  config.retry_max_interval = 30      # Longest delay to honor between retries (default: 30)
end
```

When a provider reports how long to wait through rate-limit headers (the standard `Retry-After`, or OpenAI's `x-ratelimit-reset-requests` and `x-ratelimit-reset-tokens`), retries wait that long instead of the backoff interval. If the requested wait exceeds `retry_max_interval`, the request fails immediately with `RubyLLM::RateLimitError` rather than sleeping.

These settings cover requests you can safely repeat. Requests that create something on the provider's side, such as submitting a batch, starting a video generation job, uploading a file, or creating a content cache, are sent once and raise on failure, because a retry after a lost response would create a second job.

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

### TLS Options

A self-hosted model server, such as vLLM or Ollama behind a reverse proxy, often serves HTTPS with a certificate from your company's own certificate authority. Point RubyLLM at that authority:

```ruby
RubyLLM.configure do |config|
  config.openai_api_base = "https://llm.internal.example.com/v1"
  config.ssl = { ca_file: "/certs/internal-ca.pem" }
end
```

`ssl` takes Faraday's SSL options, such as `verify`, `ca_file`, `ca_path`, `cert_store`, `client_cert`, `client_key`, `min_version`, and `max_version`, and applies them to every connection RubyLLM opens, including MCP servers and file downloads. Faraday raises `NoMethodError` for a key it doesn't know. Set it in a context to change it for one server only, such as a development server with a self-signed certificate:

```ruby
dev = RubyLLM.context { |config| config.ssl = { verify: false } }
```

It works with every Faraday adapter that honours Faraday's SSL options, including the default `:net_http`. Streaming transcription over WebSockets doesn't, and raises `ArgumentError` when `ssl` is set.

### Connection Reuse

A new connection costs a TCP and TLS handshake, which can add tens of milliseconds to a fast call. RubyLLM keeps one HTTP client for each provider endpoint and set of connection settings, shared by every call, thread, and fiber in the process. Choose an adapter that keeps connections open, and consecutive calls skip the handshake:

```ruby
# Gemfile
gem "faraday-net_http_persistent"
```

```ruby
require "faraday/net_http_persistent"

RubyLLM.configure do |config|
  config.faraday_adapter = :net_http_persistent
end
```

The default `:net_http` adapter opens a new connection for every request. `:net_http_persistent` keeps a pool that every thread draws from, which suits Puma and Sidekiq. Twenty calls to a local HTTPS server take 2.0 ms each through `:net_http`, and 0.4 ms through `:net_http_persistent`, which connects once. On Falcon or Solid Queue fiber workers, use `:async_http` from the `async-http-faraday` gem instead. It keeps connections open for as long as the Async reactor that opened them runs, so calls made outside a reactor still connect every time.

Contexts share connections when their connection settings match. Credentials travel with each request, so tenants with their own API keys reuse the same connections. A context that changes an API base, `request_timeout`, a retry setting, `http_proxy`, `ssl`, or `faraday_adapter` gets connections of its own. Each forked process, such as a Puma worker, opens its own connections instead of sharing its parent's.

## Logging & Debugging

### Basic Logging

```ruby
RubyLLM.configure do |config|
  config.log_file = "/var/log/ruby_llm.log"  # Or set RUBYLLM_LOG_FILE
  config.log_level = :info  # :debug, :info, :warn

  # Or use Rails logger
  config.logger = Rails.logger  # Overrides log_file and log_level
end
```

Log levels:
- `:debug` - Detailed request/response information
- `:info` - General operational information
- `:warn` - Non-critical issues

`log_file` notes:
- Defaults to `$stdout`
- Can also be set with `RUBYLLM_LOG_FILE=/path/to/file.log`

Debug logging is also enabled automatically when the `RUBYLLM_DEBUG=true` environment variable is set. No configuration change is needed.

Setting `config.logger` overrides `log_file` and `log_level` settings.
{: .note }

### Advanced Logging Options

Use these options when you need deeper troubleshooting or safer handling of large debug payloads.

```ruby
RubyLLM.configure do |config|
  config.log_stream_debug = true
  config.log_regexp_timeout = 1.5
end
```

`log_stream_debug` notes:
- Shows chunk-by-chunk streaming internals (accumulator state, parsing, tool chunks)
- Helps diagnose streaming and response parsing issues
- Can also be enabled with `RUBYLLM_STREAM_DEBUG=true`

`log_regexp_timeout` notes:
- Applies to regex filters used in request/response debug logging
- Uses `Regexp.timeout`
- Helps bound regex execution time when debug logs contain very large payloads

Built-in debug log redaction:
- Large base64-like blobs are redacted as `[BASE64 DATA]`
- Large embedding arrays are redacted as `[EMBEDDINGS ARRAY]`

## Contexts: Isolated Configurations

Use a context for a tenant's credentials or a task's defaults without changing global configuration.

### Basic Context Usage

```ruby
# Global config uses production OpenAI
RubyLLM.configure do |config|
  config.openai_api_key = ENV["OPENAI_PROD_KEY"]
end

ctx = RubyLLM.context do |config|
  config.openai_api_key = ENV["ANOTHER_PROVIDER_KEY"]
  config.openai_api_base = "https://another-provider.com"
  config.request_timeout = 180
end

ctx_chat = ctx.chat(model: "{{ site.models.openai_standard }}")
response = ctx_chat.ask "Process this with another provider..."

regular_chat = RubyLLM.chat  # Still uses production OpenAI
```

### Individual Operations

A context offers the same entry points as the top-level `RubyLLM` module, so the rest of the API runs under its configuration too:

```ruby
image = ctx.paint("a paper boat sailing down a rainy gutter")
image.save("boat.png")

embedding = ctx.embed("Ruby is a joy to write")
transcript = ctx.transcribe("interview.mp3")
```

`paint`, `animate`, `animate_later`, `embed`, `embed_later`, `moderate`, `speak`, `transcribe`, `ocr`, `rerank`, `upload`, `download`, `cache`, and `mcp` all use the context's keys, endpoints, and connection settings. So do the downloads RubyLLM performs on your behalf: fetching a URL attachment for a chat, or reading `image.to_blob` and `video.to_blob` from a provider's hosted file, goes through the context's `http_proxy`, `ssl`, and `request_timeout` rather than the global ones.

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
- **Coverage**: Every entry point the context exposes uses it, chat and non-chat alike, including the file downloads those calls make
- **Thread Safety**: Each context is independent and thread-safe
- **Connections**: Contexts with the same connection settings share connections, as described in [Connection Reuse](#connection-reuse)

## All Other Settings

Every setting that isn't a provider's, with its default. Provider keys and endpoints are in [Provider Setup]({% link _reference/configuration-providers.md %}#api-keys), and the [Configuration API reference]({{ '/api/RubyLLM/Configuration.html' | relative_url }}) documents each one.

| Setting | Default | What it does |
| --- | --- | --- |
| `default_model` | `"{{ site.models.default_chat }}"` | Model for `RubyLLM.chat` and agents. |
| `default_embedding_model` | `"{{ site.models.default_embedding }}"` | Model for `RubyLLM.embed`. |
| `default_image_model` | `"{{ site.models.default_image }}"` | Model for `RubyLLM.paint`. |
| `default_video_model` | `"{{ site.models.default_video }}"` | Model for `RubyLLM.animate`. |
| `default_speech_model` | `"{{ site.models.default_speech }}"` | Model for `RubyLLM.speak`. |
| `default_transcription_model` | `"{{ site.models.default_transcription }}"` | Model for `RubyLLM.transcribe`. |
| `default_ocr_model` | `"{{ site.models.default_ocr }}"` | Model for `RubyLLM.ocr`. |
| `default_moderation_model` | `"{{ site.models.default_moderation }}"` | Model for `RubyLLM.moderate`. |
| `default_judgment_model` | `"{{ site.models.judgment }}"` | Model for `RubyLLM.judge`. |
| `model_registry_file` | OS user cache directory | Path of the writable registry cache. |
| `model_registry_store` | `nil` | Object that answers `read`, and optionally `write(registry)`. |
| `request_timeout` | `300` | Seconds before a request times out. |
| `video_generation_timeout` | `600` | Seconds `animate` waits for a video. |
| `video_generation_poll_interval` | `5` | Seconds between checks on a video job. |
| `max_retries` | `3` | Retries after a transient failure. |
| `retry_interval` | `0.1` | Seconds before the first retry. |
| `retry_backoff_factor` | `2` | Multiplier for each later retry. |
| `retry_interval_randomness` | `0.5` | Random jitter factor applied to retry delays. |
| `retry_max_interval` | `30` | Longest wait between retries, in seconds. |
| `http_proxy` | `nil` | Proxy URL. |
| `ssl` | `nil` | Faraday SSL options, such as `{ ca_file: "/certs/internal-ca.pem" }`. |
| `faraday_adapter` | `:net_http` | Faraday adapter for requests. |
| `auto_upload_large_files` | `true` | Upload attachments too large to send inline. |
| `tool_concurrency` | `false` | `true` or `:threads`, or `:fibers`, to run tool calls at once. |
| `max_run_time` | `600` | Seconds a persisted chat's run may go without progress before it counts as crashed. |
| `broadcast_messages` | `false` | `acts_as_message` broadcasts chats with Turbo. The chat UI generator turns it on. |
| `split_think_tags` | `false` | `true` moves a leading `<think>` block into thinking on Chat Completions. |
| `mcp_credential_store` | `nil` | Store for MCP OAuth credentials. Rails apps use a table automatically; otherwise they stay in memory. |
| `mcp_client_name` | `"RubyLLM"` | Client name RubyLLM registers with an MCP server's authorization server. |
| `mcp_client_id` | `nil` | HTTPS URL of your OAuth client metadata document. |
| `file_converters` | `{}` | MIME types and the converters that turn a chat's files into text. |
| `sandbox` | `nil` | The name of an `MXC::Sandbox` class, or your own sandbox. |
| `sandbox_backend` | `:bubblewrap` | Or `:landlock`, which isolates less. Linux only. |
| `package_cache_dir` | OS user cache directory | Where declared gems and Python packages are kept. |
| `code_execution_max_file_size` | `10 * 1024 * 1024` | Bytes a file code execution returns may have. |
| `logger` | `nil` | A `Logger`. When set, it overrides `log_file` and `log_level`. |
| `log_file` | `$stdout`, or `RUBYLLM_LOG_FILE` | Destination of the built-in logger: a path or an IO. |
| `log_level` | `Logger::INFO`, or `DEBUG` with `RUBYLLM_DEBUG` | Severity of the built-in logger. |
| `log_stream_debug` | on with `RUBYLLM_STREAM_DEBUG` | Log raw streaming chunks. |
| `log_regexp_timeout` | `Regexp.timeout`, or `1.0` | Timeout in seconds for the regular expressions that scrub logged payloads. |
| `instrumenter` | `nil` | Object that answers `instrument(name, payload) { ... }`. |
| `deprecation_behavior` | `:warn` | `:warn`, `:silence`, or `:raise`. |
| `redact_error_messages` | `false` | `true` leaves what providers wrote out of error messages. |

## Next Steps

- [Configuration]({% link _getting_started/configuration.md %}) - API keys, default models, and the Rails initializer.
- [Provider Setup and Custom Endpoints]({% link _reference/configuration-providers.md %}) - per-provider keys and OpenAI-compatible endpoints.
- [Instrumentation and Observability]({% link _advanced/instrumentation.md %}) - hook RubyLLM into your metrics and tracing stack.
- [Model Registry]({% link _reference/models.md %}) - discover, select, and refresh models.

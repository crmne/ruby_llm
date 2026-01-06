---
layout: default
title: Observability
nav_order: 7
description: Send traces to LangSmith, DataDog, or any OpenTelemetry backend. Monitor your LLM usage in production.
redirect_from:
  - /guides/observability
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

*   How to enable OpenTelemetry tracing in RubyLLM
*   How to configure backends like LangSmith, DataDog, and Jaeger
*   How session tracking groups multi-turn conversations
*   How to add custom metadata to traces
*   What attributes are captured in spans

## What's Supported

| Feature | Status |
|---------|--------|
| Chat completions | ✅ Supported |
| Tool calls | ✅ Supported |
| Session tracking | ✅ Supported |
| Content logging (opt-in) | ✅ Supported |
| Streaming | ❌ Not yet supported |
| Embeddings | ❌ Not yet supported |
| Image generation | ❌ Not yet supported |
| Transcription | ❌ Not yet supported |
| Moderation | ❌ Not yet supported |

---

## Quick Start

### 1. Install OpenTelemetry gems

```ruby
# Gemfile
gem 'opentelemetry-sdk'
gem 'opentelemetry-exporter-otlp'
```

### 2. Enable tracing in RubyLLM

```ruby
RubyLLM.configure do |config|
  config.tracing_enabled = true
end
```

### 3. Configure your exporter

See [Backend Setup](#backend-setup) for LangSmith, DataDog, Jaeger, etc.

---

## Configuration Options

```ruby
RubyLLM.configure do |config|
  # Enable tracing (default: false)
  config.tracing_enabled = true
  
  # Log prompt/completion content (default: false)
  # Enable for full LangSmith functionality
  config.tracing_log_content = true
  
  # Max content length before truncation (default: 10000)
  config.tracing_max_content_length = 5000
end
```

> **Privacy note:** `tracing_log_content` sends your prompts and completions to your tracing backend. Only enable this if you're comfortable with your backend seeing this data.
{: .warning }

### Service Name

Your service name identifies your application in the tracing backend. Set it via environment variable:

```bash
export OTEL_SERVICE_NAME="my_app"
```

### Custom Metadata

You can attach custom metadata to traces for filtering and debugging:

```ruby
chat = RubyLLM.chat
  .with_metadata(user_id: current_user.id, request_id: request.uuid)
chat.ask("Hello!")
```

Metadata appears as `metadata.*` attributes by default. For LangSmith's metadata panel, set:

```ruby
RubyLLM.configure do |config|
  config.tracing_metadata_prefix = 'langsmith.metadata'
end
```

---

## Backend Setup

### LangSmith

LangSmith is LangChain's observability platform with specialized LLM debugging features.

```ruby
# config/initializers/ruby_llm.rb
RubyLLM.configure do |config|
  config.tracing_enabled = true
  config.tracing_log_content = true
  config.tracing_metadata_prefix = 'langsmith.metadata'
end
```

```ruby
# config/initializers/opentelemetry.rb
require 'opentelemetry/sdk'
require 'opentelemetry/exporter/otlp'

OpenTelemetry::SDK.configure do |c|
  c.add_span_processor(
    OpenTelemetry::SDK::Trace::Export::BatchSpanProcessor.new(
      OpenTelemetry::Exporter::OTLP::Exporter.new(
        endpoint: 'https://api.smith.langchain.com/otel/v1/traces',
        headers: {
          'x-api-key' => 'lsv2_pt_...',
          'Langsmith-Project' => 'my-project'
        }
      )
    )
  )
end
```

LangSmith uses the `Langsmith-Project` header (not `service_name`) to organize traces.

### Other Backends

RubyLLM works with any OpenTelemetry-compatible backend. Configure the `opentelemetry-exporter-otlp` gem to send traces to your platform of choice.

> Using DataDog, Jaeger, Honeycomb, or another platform? Consider [contributing](https://github.com/crmne/ruby_llm/blob/main/CONTRIBUTING.md) a setup example!
{: .note }

---

## What Gets Traced

### Chat Completions

Each call to `chat.ask()` creates a `ruby_llm.chat` span with:

| Attribute | Description |
|-----------|-------------|
| `gen_ai.system` | Provider name (openai, anthropic, etc.) |
| `gen_ai.request.model` | Requested model ID |
| `gen_ai.request.temperature` | Temperature setting (if specified) |
| `gen_ai.response.model` | Actual model used |
| `gen_ai.usage.input_tokens` | Input token count |
| `gen_ai.usage.output_tokens` | Output token count |
| `gen_ai.conversation.id` | Session ID for grouping conversations |

### Tool Calls

When tools are invoked, child `ruby_llm.tool` spans are created with:

| Attribute | Description |
|-----------|-------------|
| `gen_ai.tool.name` | Name of the tool |
| `gen_ai.tool.call.id` | Unique call identifier |
| `input.value` | Tool arguments (if content logging enabled) |
| `output.value` | Tool result (if content logging enabled) |

### Content Logging

When `tracing_log_content = true`, prompts and completions are logged:

| Attribute | Description |
|-----------|-------------|
| `gen_ai.prompt.0.role` | Role of first message (user, system, assistant) |
| `gen_ai.prompt.0.content` | Content of first message |
| `gen_ai.completion.0.role` | Role of response |
| `gen_ai.completion.0.content` | Response content |

---

## Session Tracking

Each `Chat` instance gets a unique `session_id`. All traces from that chat include this ID:

```ruby
chat = RubyLLM.chat
chat.ask("Hello")        # session_id: f47ac10b-58cc-4372-a567-0e02b2c3d479
chat.ask("How are you?") # session_id: f47ac10b-58cc-4372-a567-0e02b2c3d479 (same)

chat2 = RubyLLM.chat
chat2.ask("Hi")          # session_id: 7c9e6679-7425-40de-944b-e07fc1f90ae7 (different)
```

### Custom Session IDs

For applications that persist conversations, pass your own session ID to group related traces:

```ruby
chat = RubyLLM.chat(session_id: conversation.id)
chat.ask("Hello")

# Later, when user continues the conversation:
chat = RubyLLM.chat(session_id: conversation.id)
chat.ask("Follow up")  # Same session_id, grouped together
```

---

## Troubleshooting

### "I don't see any traces"

1. Verify `config.tracing_enabled = true` is set
2. Check your OpenTelemetry exporter configuration
3. Ensure the `opentelemetry-sdk` gem is installed
4. Check your backend's API key and endpoint

### "I see traces but no content"

Enable content logging:

```ruby
RubyLLM.configure do |config|
  config.tracing_log_content = true
end
```

### "My tracing backend is getting too much data"

1. Reduce `tracing_max_content_length` to truncate large messages
2. Disable content logging: `config.tracing_log_content = false`
3. Configure sampling via environment variables:

```bash
# Sample only 10% of traces
export OTEL_TRACES_SAMPLER="traceidratio"
export OTEL_TRACES_SAMPLER_ARG="0.1"
```

### "Traces aren't grouped in LangSmith"

Make sure you're reusing the same `Chat` instance for multi-turn conversations. Each `Chat.new` creates a new session.

## Next Steps

*   [Chatting with AI Models]({% link _core_features/chat.md %})
*   [Using Tools]({% link _core_features/tools.md %})
*   [Rails Integration]({% link _advanced/rails.md %})
*   [Error Handling]({% link _advanced/error-handling.md %})


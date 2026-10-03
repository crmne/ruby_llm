---
layout: default
title: OpenTelemetry
parent: Instrumentation and Observability
nav_order: 1
description: Trace RubyLLM model calls, tools, and workflows with your application's OpenTelemetry setup
---

# {{ page.title }}

{{ page.description }}
{: .fs-6 .fw-300 }

After reading this guide, you will know:

* How to enable optional OpenTelemetry tracing.
* How spans connect across model calls, tools, and workflows.
* How trace context follows concurrent tool execution.
* Which data RubyLLM exports.

## Enable Tracing

If your application already configures OpenTelemetry, enable RubyLLM tracing after that setup:

```ruby
RubyLLM::OpenTelemetry.enable
```

If your application does not have an OpenTelemetry setup, add the SDK and your exporter's gems:

```ruby
# Gemfile
gem "opentelemetry-sdk"
# Add the exporter gems your application uses.
```

Configure your SDK and exporters in your application's initializer, then enable RubyLLM tracing:

```ruby
require "ruby_llm"
require "opentelemetry/sdk"

OpenTelemetry::SDK.configure do |config|
  config.service_name = "my-app"
  # Configure your application's exporters and other instrumentation here.
end

RubyLLM::OpenTelemetry.enable
```

RubyLLM only requires `opentelemetry-api` when you call `enable`. The SDK includes that dependency. RubyLLM does not configure, start, flush, or shut down an SDK or exporter. Requiring RubyLLM alone does not load OpenTelemetry.

Enabling tracing is process-wide and safe to repeat. It also covers existing chats and isolated contexts. Your `config.instrumenter`, Rails notifications, and custom subscribers continue to receive their existing events and payloads. Call `RubyLLM::OpenTelemetry.disable` to stop tracing new operations. Spans already running still finish.

## Spans and Context

Model calls become client spans. Tool execution and workflows become internal spans. They inherit the current OpenTelemetry context, so instrumented HTTP requests and calls made inside a tool can appear beneath the RubyLLM span. Streaming spans stay open through the final response or an error. Transport retries stay within the model call; each fallback model gets its own span.

Use a [workflow]({% link _advanced/instrumentation.md %}#workflows-and-steps) to group a conversation's model calls and tools:

```ruby
RubyLLM.workflow("Answer question") do |workflow|
  workflow.step("Generate answer") do
    RubyLLM.chat.ask("What is the capital of France?")
  end
end
```

RubyLLM propagates trace context through its own thread and fiber tool concurrency. For threads, jobs, and tasks your application starts, propagate context with your application's OpenTelemetry instrumentation.

The adapter follows the [official GenAI semantic conventions](https://github.com/open-telemetry/semantic-conventions-genai/tree/main/docs/gen-ai), which are currently in development. It uses `gen_ai.provider.name`, request and response models, request settings, finish reasons, and reported token usage. Cached input is included in `gen_ai.usage.input_tokens`; cache reads and writes are also recorded separately. Unknown counts remain absent, and reported zeroes remain zeroes. Errors set the span status to error and use the Ruby exception class as `error.type`.

| RubyLLM operation | Span operation |
| --- | --- |
| Chat, including calls through agents and Rails records | `chat` |
| Embeddings | `embeddings` |
| Images and speech | `generate_content`, with `gen_ai.output.type` |
| Transcription, OCR, reranking, moderation, judgment | `transcription`, `ocr`, `rerank`, `moderation`, `judgment` |
| Tool execution | `execute_tool` |
| Workflows | `invoke_workflow` |
| Workflow steps | `ruby_llm.workflow_step` (an internal span) |

Operations without a predefined GenAI name use the RubyLLM names shown above. Workflow and step IDs use `ruby_llm.workflow.*` attributes; they are not conversation IDs. The integration does not create spans for usage notifications, raw transport events, batches, model refreshes, compaction, tokenization, video, or research jobs. It provides tracing, not metrics or log export.

## Exported Data

The adapter exports an explicit set of metadata fields. It does not export prompts, instructions, messages, generated content, embeddings, tool arguments or results, arbitrary metadata, provider options, credentials, or exception messages and stack traces. Model names, tool names, workflow names and IDs, and tool call IDs are included. Choose workflow names and IDs suitable for your telemetry destination.

The original [instrumentation payloads]({% link _advanced/instrumentation.md %}#payloads) still contain application data for your existing subscribers. Their export policy remains under your control.

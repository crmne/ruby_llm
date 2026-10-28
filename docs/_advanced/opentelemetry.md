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

* How to enable OpenTelemetry tracing.
* What a RubyLLM trace looks like.
* How spans are named and which attributes they carry.
* How trace context follows tools, threads, and jobs.
* Which data RubyLLM exports and which it keeps out.
* How to record prompts and responses when you need them.

## Enable Tracing

When an agent is slow or expensive, you want to see where the time and tokens went. OpenTelemetry shows every model call and tool run as a span in the tracing backend you already use.

If your application already configures OpenTelemetry, add one line after that setup:

```ruby
RubyLLM::OpenTelemetry.enable
```

If it does not, add the SDK and an exporter. OTLP works with most backends, including Jaeger, Honeycomb, Grafana Tempo, and Datadog:

```ruby
# Gemfile
gem "opentelemetry-sdk"
gem "opentelemetry-exporter-otlp"
```

Configure them in an initializer, such as `config/initializers/opentelemetry.rb` in Rails, then enable RubyLLM tracing:

```ruby
require "opentelemetry/sdk"
require "opentelemetry/exporter/otlp"

OpenTelemetry::SDK.configure do |config|
  config.service_name = "my-app"
end

RubyLLM::OpenTelemetry.enable
```

Point the exporter at your backend with the standard environment variables:

```sh
OTEL_EXPORTER_OTLP_ENDPOINT=https://otel.example.com:4318
OTEL_EXPORTER_OTLP_HEADERS="x-api-key=your-key"
```

RubyLLM depends only on `opentelemetry-api`, which the SDK includes, and loads it only when you call `enable`. It never configures, starts, flushes, or shuts down your SDK or exporters.

`enable` applies to the whole process, including chats that already exist and [isolated contexts]({% link _getting_started/configuration-connection.md %}#contexts-isolated-configurations). Calling it twice is harmless. Your `config.instrumenter`, Rails notifications, and other subscribers keep receiving the same events. `RubyLLM::OpenTelemetry.disable` stops tracing new operations and lets running spans finish.

## What a Trace Looks Like

Wrap related work in a [workflow]({% link _advanced/instrumentation.md %}#workflows-and-steps) to group it under one trace:

```ruby
RubyLLM.workflow("Answer question") do |workflow|
  workflow.step("Generate answer") do
    SupportAgent.new.ask("Where is order 42?")
  end
end
```

This produces a tree like:

```text
invoke_workflow Answer question
└── ruby_llm.workflow_step Generate answer
    ├── chat {{ site.models.default_chat }}
    ├── execute_tool lookup_order
    │   └── GET /orders/42          (from your HTTP instrumentation)
    └── chat {{ site.models.default_chat }}
```

The agent asks the model, runs the tool the model chose, then asks the model again with the result. Each RubyLLM span uses the current OpenTelemetry context, so spans from your other instrumentation, such as the HTTP call inside the tool, appear beneath it. Without a workflow, each model call starts its own trace, or joins the trace already active, such as a Rails request.

A few details:

* A streaming call's span stays open until the final chunk or an error.
* Retries happen inside one model call's span. Each fallback model gets its own span.
* [Evaluations]({% link _advanced/evaluation-progress.md %}#tracing) run every trial as a workflow, so each trial appears as its own trace.

## Spans

Span names follow the pattern `<operation> <target>`. The target is the model for model calls, the tool name for tools, the language for code execution runs, and the workflow or step name for workflows.

| RubyLLM operation | Operation name | Span kind |
| --- | --- | --- |
| Chat, including Agents and Rails chat records | `chat` | Client |
| Embeddings | `embeddings` | Client |
| Images and speech | `generate_content` | Client |
| Transcription | `transcription` | Client |
| OCR | `ocr` | Client |
| Reranking | `rerank` | Client |
| Moderation | `moderation` | Client |
| Judgments | `judgment` | Client |
| Tool execution | `execute_tool` | Internal |
| Code execution runs | `ruby_llm.code_execution` | Internal |
| Workflows | `invoke_workflow` | Internal |
| Workflow steps | `ruby_llm.workflow_step` | Internal |

There are no spans for usage events, raw HTTP requests, batches, model refreshes, compaction, tokenization, video generation, or research jobs. RubyLLM exports traces only, not metrics or logs.

## Attributes

Spans follow the [OpenTelemetry GenAI semantic conventions](https://github.com/open-telemetry/semantic-conventions-genai/tree/main/docs/gen-ai), which are still in development.

| Attribute | Contents |
| --- | --- |
| `gen_ai.operation.name` | The operation name from the table above |
| `gen_ai.provider.name` | The provider, such as `openai`, `anthropic`, or `aws.bedrock` |
| `gen_ai.request.model` | The model you asked for |
| `gen_ai.response.model` | The model the provider reports running |
| `gen_ai.request.temperature`, `gen_ai.request.max_tokens`, `gen_ai.request.stream` | Request settings, when set |
| `gen_ai.output.type` | `json` for structured output, `image`, or `speech` |
| `gen_ai.response.finish_reasons` | Why the model stopped |
| `gen_ai.usage.input_tokens` | Input tokens, including cached input |
| `gen_ai.usage.output_tokens` | Output tokens |
| `gen_ai.usage.cache_read.input_tokens`, `gen_ai.usage.cache_write.input_tokens` | Cached input, also counted in the input total |
| `gen_ai.usage.reasoning.output_tokens` | Thinking tokens |
| `gen_ai.tool.name`, `gen_ai.tool.call.id` | The tool and its call ID |
| `gen_ai.workflow.name`, `ruby_llm.workflow.id` | The workflow name and ID |
| `ruby_llm.workflow.step.name`, `ruby_llm.workflow.step.id` | The step name and ID |
| `ruby_llm.code_execution.language`, `ruby_llm.code_execution.exit_code`, `ruby_llm.code_execution.timed_out`, `ruby_llm.code_execution.duration` | A code execution run's language, exit code, timeout, and duration in seconds |

Token counts the provider did not report are left out, and reported zeroes stay zero. When an operation raises, the span's status is set to error and `error.type` holds the exception class.

## Context Across Threads and Jobs

RubyLLM carries the trace context into the threads and fibers it starts for [concurrent tool execution]({% link _core_features/tool-execution.md %}), so those tools stay in the right trace. For threads, jobs, and tasks your application starts, propagate context with your OpenTelemetry instrumentation, such as `opentelemetry-instrumentation-active_job`.

## Exported Data

Traces often go to a third-party service, so by default RubyLLM exports only the metadata listed above. It does not export prompts, instructions, messages, generated content, or tool arguments and results unless you [record content](#recording-content). It never exports embeddings, attachment bytes, metadata you attach, provider options, credentials, or exception messages and stack traces.

Model names, tool names, tool call IDs, and workflow names and IDs are exported. Choose workflow names and IDs that are safe to send to your tracing backend.

The [instrumentation events]({% link _advanced/instrumentation.md %}#payloads) your own subscribers receive still contain the full application data. What you do with it is up to you.

## Recording Content

Sometimes you want to see what the model was asked and what it said: to debug a bad answer in development, or to run evaluations over traces in an observability platform. Turn on content recording:

```ruby
RubyLLM::OpenTelemetry.enable(content: true)
```

Chat spans then carry the conversation, and tool spans carry what each tool received and returned:

| Attribute | Contents |
| --- | --- |
| `gen_ai.system_instructions` | The chat's instructions |
| `gen_ai.input.messages` | The messages sent to the model, with their tool calls and results |
| `gen_ai.output.messages` | The model's reply and why it stopped |
| `gen_ai.tool.call.arguments` | The arguments a tool was called with |
| `gen_ai.tool.call.result` | What the tool returned |

Messages follow the GenAI conventions' message format, recorded as JSON strings. Attachments appear as their type, MIME type, and URL, provider file ID, or filename, never as their bytes.

Content often includes personal data, so record it only where your tracing backend may hold it. To decide per environment, pass a setting:

```ruby
RubyLLM::OpenTelemetry.enable(content: ENV["OTEL_INSTRUMENTATION_GENAI_CAPTURE_MESSAGE_CONTENT"] == "true")
```

Calling `enable` again without `content: true` stops recording content for new spans.

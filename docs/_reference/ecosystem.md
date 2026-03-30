---
layout: default
title: RubyLLM Ecosystem
nav_order: 3
description: Extend RubyLLM with MCP servers, structured schemas, instrumentation, monitoring and community-built tools for production AI apps.
---

# {{ page.title }}
{: .no_toc }

{{ page.description }}
{: .fs-6 .fw-300 }

> Ecosystem projects are maintained by their respective authors. We list projects for discoverability, but we cannot guarantee the quality, security, maintenance status, or fitness of every listed project.
{: .note }

## Table of contents
{: .no_toc .text-delta }

1. TOC
{:toc}

---

After reading this guide, you will know:

* How `RubyLLM::Schema` simplifies structured data definition for AI applications
* What the Model Context Protocol (MCP) is and how `RubyLLM::MCP` brings it to Ruby
* How `RubyLLM::Instrumentation` exposes RubyLLM events through ActiveSupport notifications
* How `RubyLLM::Monitoring` provides dashboards and alerts for RubyLLM activity
* How `RubyLLM::RedCandle` enables local model execution from Ruby
* How OpenTelemetry instrumentation for RubyLLM provides observability into your LLM applications
* Where to find community projects and how to contribute your own

## RubyLLM::Schema

**Ruby DSL for JSON Schema Creation**

[`RubyLLM::Schema`](https://github.com/danielfriis/ruby_llm-schema) provides a clean, Rails-inspired DSL for creating JSON schemas. It's designed specifically for defining structured data schemas for LLM function calling and structured outputs.

### Why Use RubyLLM::Schema?

When working with LLMs, you often need to define precise data structures for:

- Structured output formats
- Function parameter schemas
- Data validation schemas
- API response formats

`RubyLLM::Schema` makes this easy with a familiar Ruby syntax.

### Key Features

- Rails-inspired DSL for intuitive schema creation
- Full JSON Schema compatibility
- Support for primitive types, objects, and arrays
- Union types with `any_of`
- Schema definitions and references for reusability

### Installation

```bash
gem install ruby_llm-schema
```

For detailed documentation and examples, visit the [RubyLLM::Schema repository](https://github.com/danielfriis/ruby_llm-schema).

---

## RubyLLM::MCP

**Model Context Protocol Support for Ruby**

[`RubyLLM::MCP`](https://github.com/patvice/ruby_llm-mcp) brings the [Model Context Protocol](https://modelcontextprotocol.io/) to Ruby, enabling your applications to connect to MCP servers and use their tools, resources, and prompts as part of LLM conversations.

### What is MCP?

The Model Context Protocol is an open standard that allows AI applications to integrate with external data sources and tools. MCP servers can expose:

- **Tools**: Functions that LLMs can call to perform actions
- **Resources**: Structured data that can be included in conversations
- **Prompts**: Predefined prompt templates with parameters

### Key Features

- Multiple transport types (HTTP streaming, STDIO, SSE)
- Automatic tool integration with RubyLLM
- Resource management for files and data
- Prompt templates with arguments
- Support for multiple simultaneous MCP connections

### Installation

```bash
gem install ruby_llm-mcp
```

For detailed documentation, examples, and usage guides, visit the [RubyLLM::MCP documentation](https://rubyllm-mcp.com/).

---

## RubyLLM::Instrumentation

**ActiveSupport::Notifications instrumentation for RubyLLM**

[`RubyLLM::Instrumentation`](https://github.com/sinaptia/ruby_llm-instrumentation) is a Rails plugin that instruments RubyLLM events with the built-in [ActiveSupport::Notifications](https://api.rubyonrails.org/classes/ActiveSupport/Notifications.html) API.

### Why Use RubyLLM::Instrumentation?

When building LLM applications, you may need custom monitoring, analytics, or logging pipelines based on your RubyLLM activity.

### Key Features

- Event instrumentation for key RubyLLM operations
- Native integration with `ActiveSupport::Notifications`
- Event hooks for chat completion, tools, embeddings, images, moderation, and transcription
- Easy integration with existing Rails observability stacks

### Supported Events

- `complete_chat.ruby_llm` when `RubyLLM::Chat#ask` is called
- `execute_tool.ruby_llm` when a tool call is executed
- `embed_text.ruby_llm` when `RubyLLM::Embedding.embed` is called
- `paint_image.ruby_llm` when `RubyLLM::Image.paint` is called
- `moderate_text.ruby_llm` when `RubyLLM::Moderation.moderate` is called
- `transcribe_audio.ruby_llm` when `RubyLLM::Transcription.transcribe` is called

### Installation

```bash
gem install ruby_llm-instrumentation
```

For detailed documentation and examples, visit the [RubyLLM::Instrumentation repository](https://github.com/sinaptia/ruby_llm-instrumentation).

---

## RubyLLM::Monitoring

**RubyLLM monitoring within your Rails application**

[`RubyLLM::Monitoring`](https://github.com/sinaptia/ruby_llm-monitoring) is a Rails engine that provides a dashboard for cost, throughput, response time, and error aggregations. It also supports configurable alerts through channels such as email or Slack.

### Why Use RubyLLM::Monitoring?

When running RubyLLM-powered features in production, you need ongoing visibility into performance, cost, and failure patterns.

### Key Features

- Captures events from `RubyLLM::Instrumentation`
- Dashboard metrics for cost, throughput, latency, and error rates
- Rule-based alerting for operational thresholds and regressions

### Installation

```bash
gem install ruby_llm-monitoring
```

For detailed documentation and examples, visit the [RubyLLM::Monitoring repository](https://github.com/sinaptia/ruby_llm-monitoring).

---

## RubyLLM::RedCandle

**Local LLM Execution with Quantized Models**

[`RubyLLM::RedCandle`](https://github.com/scientist-labs/ruby_llm-red_candle) enables local LLM execution using quantized GGUF models through the [Red Candle](https://github.com/scientist-labs/red-candle) gem. Unlike other RubyLLM providers that communicate via HTTP APIs, `RubyLLM::RedCandle` runs models directly in your Ruby process using Rust's Candle library.

### Why Run Models Locally?

Running LLMs locally offers several advantages:

- **Zero latency**: No network round-trips to external APIs
- **No API costs**: Run unlimited inferences without usage fees
- **Complete privacy**: Your data never leaves your machine
- **Offline capable**: Works without an internet connection

### Key Features

- Local inference with hardware acceleration (Metal on macOS, CUDA for NVIDIA GPUs, or CPU fallback)
- Automatic model downloading from HuggingFace
- Streaming support for token-by-token output
- Structured JSON output with grammar-constrained generation
- Multi-turn conversation support with automatic history management

### Installation

```bash
gem install ruby_llm-red_candle
```

**Note**: The underlying red-candle gem requires a Rust toolchain for compiling native extensions.

### Supported Models

`RubyLLM::RedCandle` supports various quantized models including TinyLlama, Qwen2.5, Gemma-3, Phi-3, and Mistral-7B. Models are automatically downloaded from HuggingFace on first use.

For detailed documentation and examples, visit the [RubyLLM::RedCandle repository](https://github.com/scientist-labs/ruby_llm-red_candle).

---

## OpenTelemetry RubyLLM Instrumentation

**Observability for RubyLLM Applications**

[opentelemetry-instrumentation-ruby_llm](https://github.com/thoughtbot/opentelemetry-instrumentation-ruby_llm) adds OpenTelemetry tracing to RubyLLM, enabling you to send traces to any compatible backend (Langfuse, Datadog, Honeycomb, Jaeger, Arize Phoenix and more).

### Why Use OpenTelemetry Instrumentation?

When running LLM applications in production, you need visibility into:

- Which models are being called and how they perform
- The flow of conversations and tool calls
- How long each step takes and where time is spent
- Token usage for cost tracking and optimization
- Tool call selection, execution, and results
- Error rates and failure modes

This gem provides all of this automatically, with minimal setup and without having to manually add tracing code to your application.

### Key Features

- Automatic tracing for chat completions and tool calls
- Token usage tracking (input and output)
- Tool call spans with arguments and results
- Error recording with exception details
- Works with any OpenTelemetry-compatible backend
- Follows the [OpenTelemetry GenAI Semantic Conventions](https://opentelemetry.io/docs/specs/semconv/gen-ai/gen-ai-spans/)

### Installation

```bash
gem install opentelemetry-instrumentation-ruby_llm
```

### Usage

```ruby
OpenTelemetry::SDK.configure do |c|
  c.use 'OpenTelemetry::Instrumentation::RubyLLM'
end
```

For detailed documentation, setup instructions, and examples, visit the [OpenTelemetry RubyLLM Instrumentation repository](https://github.com/thoughtbot/opentelemetry-instrumentation-ruby_llm).

---

## Community Projects

The RubyLLM ecosystem is growing! If you've built a library or tool that extends RubyLLM, we'd love to hear about it. Consider:

- Opening a PR to add your project to this page
- Sharing it in our GitHub Discussions
- Using the `ruby-llm` topic on your GitHub repository

Together, we're building a comprehensive ecosystem for LLM-powered Ruby applications.

---
layout: default
title: RubyLLM Ecosystem
nav_order: 5
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
* How to test application code by stubbing responses with `RubyLLM::Test`
* How `RubyLLM::Contract` adds runtime contracts, model-escalating retries, and regression evals on top of RubyLLM
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

## RubyLLM::Tribunal

**LLM Evaluation and Testing for Ruby**

[`RubyLLM::Tribunal`](https://github.com/Alqemist-labs/ruby_llm-tribunal) helps you evaluate and test LLM outputs in Ruby applications. It combines deterministic assertions for fast checks with model-based evaluations for quality, faithfulness, and safety.

### Why Use RubyLLM::Tribunal?

When building LLM features, you often need to verify that responses are:

- Grounded in retrieved context
- Relevant to the user's request
- Free from hallucinations or unsafe content
- Resistant to jailbreak or prompt injection attempts

`RubyLLM::Tribunal` brings these checks into your RSpec or Minitest suite.

### Key Features

- Deterministic assertions for exact matches, regexes, JSON validation, and other fast checks
- LLM-as-judge assertions for faithfulness, relevance, correctness, and refusal behavior
- Assertions for hallucinations, toxicity, harmful content, bias, jailbreaks, and PII exposure
- Red team attacks to generate adversarial prompts and test defenses
- Multiple reporters including Console, JSON, HTML, JUnit, and GitHub Actions
- Test helpers for RSpec and Minitest

### Installation

```bash
gem install ruby_llm-tribunal
```

For detailed documentation and examples, visit the [RubyLLM::Tribunal repository](https://github.com/Alqemist-labs/ruby_llm-tribunal).

---

## RubyLLM::Contract

**Contracts and Evals for LLM Outputs**

[`RubyLLM::Contract`](https://github.com/justi/ruby_llm-contract) wraps `RubyLLM::Chat` with input/output contracts, business-rule validation, retry with model escalation, pre-flight cost ceilings, and a regression-eval framework. It catches schema-valid-but-logically-wrong output before it reaches your code.

### Why Use RubyLLM::Contract?

LLMs can return JSON that looks correct - valid shape, right types, right fields - while being silently wrong in ways schema validation alone doesn't catch. You often need:

- Business rules that schema can't express
- Retry with model escalation when a cheap model's output fails the contract
- Regression evals with baselines to block prompt regressions in CI
- Pre-flight cost ceilings so a large input doesn't blow your budget

### Key Features

- Class-based DSL: `prompt`, `output_schema`, `validate`, `retry_policy`, `max_cost`
- Schema validation via [`RubyLLM::Schema`](https://github.com/danielfriis/ruby_llm-schema) with client-side verification
- Model escalation on validation failure and pre-flight refusal on cost limits
- LLM-as-judge checks and a regression eval framework with frozen datasets and baselines
- Pipeline composition with fail-fast and per-step models
- RSpec / Minitest matchers (`pass_eval`, `satisfy_contract`, `stub_step`)

`RubyLLM::Contract` is runtime - it gates the LLM call and retries on failure - while [`RubyLLM::Tribunal`](https://github.com/Alqemist-labs/ruby_llm-tribunal) grades outputs at test time; the two compose well in the same project.

### Installation

```bash
gem install ruby_llm-contract
```

For detailed documentation and examples, visit the [RubyLLM::Contract repository](https://github.com/justi/ruby_llm-contract).

---

## RubyLLM::TopSecret

**Automatically filter sensitive information from RubyLLM conversations using Top Secret.**

[`RubyLLM::TopSecret`](https://github.com/thoughtbot/ruby_llm-top_secret) automatically filters sensitive information from your conversations using [`Top Secret`](https://github.com/thoughtbot/top_secret).

### Why Use RubyLLM::TopSecret?

If you're working in a regulated industry, or have general privacy concerns,
you should be cautious about what data you send to an LLM. `RubyLLM::TopSecret`
not only filters sensitive information before sending it to a provider,
but it also restores the filtered response server-side.

### Key Features

- Supports in-memory and Active Record backed chats
- Opt-in first architecture

### Installation

```bash
gem install ruby_llm-top_secret
```

## Usage

```ruby
RubyLLM::TopSecret.with_filtering do
  chat = RubyLLM.chat
  response = chat.ask("My name is Ralph and my email is ralph@thoughtbot.com")

  # The provider receives: "My name is [PERSON_1] and my email is [EMAIL_1]"
  puts response.content
  # => "Nice to meet you, Ralph!"
end
```

For detailed documentation and examples, visit the [RubyLLM::TopSecret repository](https://github.com/thoughtbot/ruby_llm-top_secret?tab=readme-ov-file).

---

## RubyLLM::Test

**Test Application Code by Stubbing LLM Responses**

[`RubyLLM::Test`](https://github.com/RockSolt/ruby_llm-test) allows you to stub LLM responses in your tests, making it easier to test application logic without relying on calls to external systems.

### Why Use RubyLLM::Test?

When writing tests for code that interacts with LLMs, you may want to:

- Ensure your application logic behaves correctly without making real API calls
- Test edge cases and error handling
- Control the responses from the LLM for deterministic tests

### Key Features

- Clear syntax for defining stubs and expected responses
- Support for multiple stubs in a single test
- Validate arguments, such as model or tool calls, passed to the LLM
- Works with RSpec and Minitest

### Usage

```ruby
RubyLLM::Test.stub_response("Outlook good")

chat = RubyLLM.chat
response = chat.ask "What are the odds this works?"

assert_equal "Outlook good", response.content
```

### Installation

Add the gem to the test group in your Gemfile, or install it directly:

```bash
gem install ruby_llm-test
```

---

## RubyLLM::Instructor

**Structured, Validated Outputs with Automatic Retry**

[`RubyLLM::Instructor`](https://github.com/washu/ruby_llm-instructor) returns fully-hydrated, validated Ruby objects from LLM calls. Define a plain Ruby class or ActiveModel, pass it as `response_model`, and get back an instance of that class — with validation errors automatically fed back to the LLM for retry.

### Why Use RubyLLM::Instructor?

Structured output gets you JSON in the right shape, but it doesn't guarantee the *values* are valid. When extracting data from unstructured text, you often need:

- Domain validation (phone formats, presence, numeric ranges) enforced before the result reaches your code
- Automatic re-prompting with the specific validation errors when the model gets it wrong
- Real Ruby objects, not hashes, as the return value

`RubyLLM::Instructor` closes the loop between schema, validation, and retry.

### Key Features

- Duck-typed response models — no base class or mixin required
- Schema inferred automatically from `attr_accessor` or ActiveModel attributes
- ActiveModel validations run on every response; errors are sent back to the LLM on retry
- Works with every provider `ruby_llm` supports — same code for OpenAI, Anthropic, Gemini, and more
- Integrates with `RubyLLM::Schema` for explicit schema control

### Installation

```
gem install ruby_llm-instructor
```

For detailed documentation and examples, visit the [RubyLLM::Instructor repository](https://github.com/washu/ruby_llm-instructor).

---

## RubyLLM::Registry

**Local-First, Versioned Prompt Storage and Rendering**

[`RubyLLM::Registry`](https://github.com/washu/ruby_llm-registry) treats prompts as immutable, semantically versioned artifacts stored outside your application code — with label resolution, ERB rendering, and revision diffing.

### Why Use RubyLLM::Registry?

Prompts embedded in code change silently with every deploy. In production you need:

- A history of every prompt revision, with the ability to pin or roll back
- Environment labels like `production` and `staging` that move independently of code
- Validation that every required variable is supplied before a prompt is rendered
- Diffs between revisions so you can see exactly what changed

`RubyLLM::Registry` provides all of this with a filesystem-first design and zero required infrastructure.

### Key Features

- Semantic versioning per prompt (`v1.0.0.md`, `v1.2.3.md`) with latest/pinned/label resolution
- YAML front matter for labels, required variables, and metadata
- ERB template rendering with required-variable validation
- Export/import as YAML, JSON, or Markdown
- Field and body diffs between prompt revisions
- Optional, lazily-loaded backends: SQLite, ActiveRecord, MongoDB, or S3

### Installation

```
gem install ruby_llm-registry
```

For detailed documentation and examples, visit the [RubyLLM::Registry repository](https://github.com/washu/ruby_llm-registry).

---

## RubyLLM::Tokenizer

**Local, Model-Aware Token Counting and Truncation**

[`RubyLLM::Tokenizer`](https://github.com/washu/ruby_llm-tokenizer) maps model identifiers (`gpt-4o`, `llama-3`, `mistral`, …) to the correct tokenizer and counts, analyzes, or truncates text against a model's context window — entirely locally, without an API call.

### Why Use RubyLLM::Tokenizer?

Token counts drive cost, context-window budgeting, and chunking decisions, but each model family uses a different tokenizer. You often need to:

- Count tokens before sending a request, to estimate cost or enforce budgets
- Truncate logs, documents, or chat history to fit a context window — keeping the newest or oldest content
- Inspect exactly how a model tokenizes a string when debugging prompts

`RubyLLM::Tokenizer` does all of this with the right tokenizer for each model, selected automatically.

### Key Features

- Unified facade over Hugging Face `tokenizers`, `tiktoken_ruby`, and SentencePiece bindings
- Automatic model-to-tokenizer mapping for major model families
- `count`, `analyze` (ids, tokens, encoding), and `truncate` APIs
- Context-window truncation with `:truncate_left` / `:truncate_right` overflow strategies
- Streaming/`Enumerable` input support — truncate huge files without materializing them
- No Rust toolchain required — cross-compiled binaries inherited from upstream gems

### Installation

```
gem install ruby_llm-tokenizer
```

For detailed documentation and examples, visit the [RubyLLM::Tokenizer repository](https://github.com/washu/ruby_llm-tokenizer).

---

## RubyLLM::Turbovec

**Embeddable, In-Process Quantized Vector Search**

[`RubyLLM::Turbovec`](https://github.com/washu/ruby_llm-turbovec) is a native Rust extension (built with `magnus` and `rb-sys`) that wraps the [`turbovec`](https://crates.io/crates/turbovec) crate, providing fast quantized vector search inside your Ruby process — no external vector database required.

### Why Use RubyLLM::Turbovec?

Most vector search options in Ruby require running and connecting to a separate service (Qdrant, Milvus) or a Postgres extension (pgvector). For many RAG and semantic-search workloads you'd rather:

- Embed the index directly in your application process, with no network hop or service to operate
- Persist an index to disk and reload it, like a file-backed store
- Keep stable external IDs alongside vectors so search results map back to your records
- Sustain read-heavy search traffic without a global lock bottleneck

`RubyLLM::Turbovec` is the in-process, file-backed option for those cases.

### Key Features

- Native Rust extension wrapping the real `turbovec` crate via `magnus`/`rb-sys`
- Positional index (`TurboQuantIndex`) and stable ID-based index (`IdMapIndex`)
- Quantized vectors for compact memory footprint
- Disk persistence with `write`/`load` (`.tv` / `.tvim`)
- Read/write lock around the underlying indexes so concurrent reads avoid a single global mutex
- `cargo test --locked` runs against the native crate in CI, not just the Ruby wrapper

### Installation

```
gem install ruby_llm-turbovec
```

Requires a Rust toolchain, as the native extension compiles during installation.

For detailed documentation and examples, visit the [RubyLLM::Turbovec repository](https://github.com/washu/ruby_llm-turbovec).

---





## Community Projects

The RubyLLM ecosystem is growing! If you've built a library or tool that extends RubyLLM, we'd love to hear about it. Consider:

- Opening a PR to add your project to this page
- Sharing it in our GitHub Discussions
- Using the `ruby-llm` topic on your GitHub repository

Together, we're building a comprehensive ecosystem for LLM-powered Ruby applications.

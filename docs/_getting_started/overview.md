---
layout: default
title: How RubyLLM Works
nav_order: 2
description: Understand RubyLLM's public API, its providers and protocols, and the services they share.
redirect_from:
  - /guides/overview
---

# {{ page.title }}

{{ page.description }}
{: .fs-6 .fw-300 }

After reading this guide, you will know:

* How the RubyLLM API covers conversations and individual AI operations.
* What providers do and what protocols do.
* How model selection, configuration, and usage tracking work across the API.
* How Rails integration adds persistence, attachments, streaming, and jobs.

RubyLLM is an AI framework for Ruby and Rails. You build with its Ruby API: text generation and conversations on one side, individual AI operations on the other. Providers and protocols connect that API to AI services. Rails integration brings it into your application with the conventions you already use.

## The RubyLLM API

### Text Generation and Conversations

A `Chat` holds the conversation and its settings. Calling `ask` adds your question, generates a response, runs any tool calls, and returns a `Message`:

```ruby
chat = RubyLLM.chat(model: "{{ site.models.default_chat }}")
response = chat.ask "Help me plan a Ruby study group."
puts response.content
```

The conversation API provides:

* **Messages and attachments** for text, images, audio, and documents the model supports.
* **Streaming** to display a response as it arrives.
* **Tools** that let the model call your Ruby code, with optional human approval before execution.
* **Structured output** for results you read as a Hash through `response.parsed`.
* **Agents** that put a model, instructions, tools, and other settings in a reusable Ruby class.
* **Loop control** to generate a response, run tools, or advance one step at a time.

An agent uses the same conversation API:

```ruby
class StudyPlanner < RubyLLM::Agent
  model "{{ site.models.default_chat }}"
  instructions "Help organize practical Ruby study sessions."
end

response = StudyPlanner.new.ask "Plan a session about Ruby blocks."
```

Use ordinary Ruby methods and jobs to coordinate agents. [Agentic Workflows]({% link _advanced/agentic-workflows.md %}) covers handoffs and explicit loop control; [Durable Agents]({% link _advanced/durable-agents.md %}) covers resuming work across jobs and deploys.

### Individual AI Operations

These operations take an input and return a result without maintaining a conversation. Use them directly:

```ruby
image = RubyLLM.paint "A watercolor illustration of a Ruby study group"
image.save "study_group.png"
```

Use `paint` for [images]({% link _core_features/image-generation.md %}), `animate` for [video]({% link _core_features/video-generation.md %}), and `speak` for [speech]({% link _core_features/text-to-speech.md %}). In the other direction, `transcribe` turns [audio into text]({% link _core_features/audio-transcription.md %}) and `ocr` extracts [document text]({% link _core_features/ocr.md %}).

For search, `embed` creates [vectors]({% link _core_features/embeddings.md %}) and `rerank` orders [candidate documents by relevance]({% link _core_features/rerank.md %}). Use `moderate` to check [content flags and categories]({% link _core_features/moderation.md %}).

Each result has readers for its output, such as `transcription.text`, `document.markdown`, or `embedding.vectors`. Generated images, video, and speech have a `save` method.

An individual operation may involve several requests. `animate` submits a job and waits for the video; `animate_later` returns a `VideoJob` immediately. Transcription can stream. You use the same operation API while RubyLLM handles that lifecycle.

## Providers and Protocols

Your Ruby code describes the work. Providers and protocols translate it into calls to a particular service.

### Providers

A provider represents the service you use. It supplies the base URL, authentication, configuration, and model catalog. It also selects the protocol for a model and supplies service-specific settings or routing rules.

For example, OpenAI and Ollama have different hosts and authentication requirements, but both can use the Chat Completions protocol. One provider can also expose several protocols: OpenAI supports Responses and Chat Completions, while Vertex AI routes models to several API formats.

### Protocols

A protocol implements an API format. It renders requests, parses responses, handles streaming events, and turns service errors into RubyLLM errors. Examples include Chat Completions, Responses, Anthropic, Gemini, and Converse.

Services sometimes differ from the protocol they implement. A provider can select a small dialect of an existing protocol for those differences. Request and response format changes stay in the protocol; service URLs, credentials, and catalog rules stay in the provider. Your chat, tool, or agent does not need to know those details.

A service that implements an existing protocol can be supported without writing its request format again. See [Custom Providers and Protocols]({% link _reference/custom-providers.md %}) for extending this layer.

## What They Share

### Model and Provider Selection

The [Model Registry]({% link _reference/models.md %}) records which providers offer each model, its capabilities, limits, and pricing. RubyLLM uses it to resolve a model name to a provider:

```ruby
chat = RubyLLM.chat(model: "{{ site.models.default_chat }}")
chat.model.provider
# => "openai"
```

Pass `provider:` when you want to choose the service explicitly. You still need its credentials configured. [Model Resolution]({% link _reference/model-resolution.md %}) explains aliases and selection when several providers offer the same model.

Capabilities depend on the model. Query them through the registry, or browse the [Models]({% link _reference/available-models.md %}) page:

```ruby
model = RubyLLM.models.find("{{ site.models.openai_tools }}")
model.supports?(:vision)
model.supports?(:function_calling)
```

### Protocol Selection

The provider chooses a protocol for the model and operation. For conversations, you can override its default:

```ruby
chat = RubyLLM.chat(
  model: "{{ site.models.default_chat }}",
  provider: :openai,
  protocol: :chat_completions
)
```

The chat still returns `Message` objects and uses the same tools and callbacks. See [Choosing the Wire Protocol]({% link _core_features/chat-request-control.md %}#choosing-the-wire-protocol).

### Configuration

Set application-wide defaults with `RubyLLM.configure`. Use a `Context` for an isolated set of credentials or defaults, such as one tenant's configuration. Contexts expose the same entry points, including `chat`, `paint`, and `embed`:

```ruby
context = RubyLLM.context do |config|
  config.openai_api_key = tenant.api_key
end

chat = context.chat
```

Set conversation-specific options with chainable methods such as `with_instructions` and `with_tools`. Use shared RubyLLM options where available; `provider_options` carries fields specific to a service. See [Configuration]({% link _getting_started/configuration.md %}).

### Usage, Costs, and Instrumentation

Read usage from a response:

```ruby
response = chat.ask "Explain Ruby blocks."
response.tokens.input
response.tokens.output
response.cost.total
```

The accounting follows provider attempts, so a successful answer can include the cost of earlier failed attempts. Unknown costs stay unknown. In Rails, the usage ledger keeps those attempts separately from messages. See [Cost and Usage Tracking]({% link _core_features/cost-and-usage-tracking.md %}).

[Instrumentation]({% link _advanced/instrumentation.md %}) lets you observe calls across chats, tools, and individual operations. `RubyLLM.workflow` groups events from ordinary Ruby code into a named workflow.

### Background Work and Provider Resources

[Batches]({% link _advanced/batches.md %}) submit chats or embedding requests for provider-side processing. Stage them with `ask_later` or `embed_later` and submit them with `RubyLLM.batch`.

[File Storage]({% link _core_features/files.md %}) handles provider uploads and downloads with `RubyLLM.upload` and `RubyLLM.download`. [Prompt Caching]({% link _core_features/prompt-caching.md %}) supports reusing prompt content, including provider-managed caches through `RubyLLM.cache`.

[Error Handling]({% link _advanced/error-handling.md %}) provides common exceptions, retries, and model fallbacks. These services support the public API without requiring you to manage each provider's request format.

## Rails Integration

Rails integration keeps the Ruby API and adds the parts a Rails application needs. `acts_as_chat` and `acts_as_message` give your Active Record models the same conversation methods as the plain-Ruby objects:

```ruby
class Chat < ApplicationRecord
  acts_as_chat
end

class Message < ApplicationRecord
  acts_as_message
end

chat = Chat.create!(model: "{{ site.models.default_chat }}")
response = chat.ask "Help me plan a Ruby study group."
```

RubyLLM owns the supporting model-registry, tool-call, usage, and batch tables. Your application keeps its users, permissions, and other relationships on its own records. The framework can evolve its supporting data without asking you to maintain those models.

With [Active Record]({% link _advanced/rails-persistence.md %}), you can reload conversations, restore agents, and read usage through associations. Pass [Active Storage attachments]({% link _core_features/attachments.md %}) with `with:`, just as you pass a file in plain Ruby.

Use [Hotwire]({% link _advanced/rails-streaming.md %}) to stream replies into a page and [Active Job]({% link _advanced/durable-agents.md %}) to run agents in your existing job backend. Persisted agents can resume their work in another process.

The [generators]({% link _advanced/rails-generators.md %}) set up these pieces in conventional Rails directories. They create persistence, agents, tools, schemas, and an optional chat UI with streaming already connected.

Individual operations such as `paint`, `transcribe`, and `ocr` also work directly in your Rails services and jobs. See [Rails Integration]({% link _advanced/rails.md %}) to get started.

## How the Parts Fit Together

| Part | In practice |
| --- | --- |
| Ruby API: conversations | Chats, messages, tools, agents, structured output, and streaming. |
| Ruby API: individual operations | Images, video, speech, transcription, OCR, moderation, embeddings, and reranking. |
| Providers and protocols | Providers choose the service and its settings; protocols translate the API format. |
| Shared services | Model selection, configuration, usage and costs, instrumentation, batches, and provider resources. |
| Rails integration | The same API with Active Record, Active Storage, Hotwire, jobs, and generators. |

## Next Steps

Try the examples in [Getting Started]({% link _getting_started/getting-started.md %}), then follow the guide for the feature you want to build.

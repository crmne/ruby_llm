---
layout: default
title: How RubyLLM Works
nav_order: 2
description: See how conversations, individual AI operations, providers, shared services, and Rails fit together in RubyLLM.
redirect_from:
  - /guides/overview
---

# {{ page.title }}

{{ page.description }}
{: .fs-6 .fw-300 }

After reading this guide, you will know:

* How conversations and individual AI operations divide the RubyLLM API.
* What providers do for you.
* How model selection, configuration, and usage tracking work across the API.
* What Rails integration adds.

RubyLLM is an AI framework for Ruby and Rails. You build with its Ruby API: conversations on one side, individual AI operations on the other. Providers connect that API to AI services, and Rails integration brings it into your application with the conventions you already use.

This guide follows the support desk from [Getting Started]({% link _getting_started/getting-started.md %}) through each part.

## Conversations

A `Chat` holds a conversation and its settings. `ask` adds your message, gets the model's answer, runs any tools the model calls, and returns a `Message`:

```ruby
chat = RubyLLM.chat(model: "{{ site.models.default_chat }}")
response = chat.ask "A customer's parcel arrived damaged. Draft a short reply."
puts response.content
```

Everything that involves a conversation builds on `Chat`:

* **Messages and attachments**: text, images, audio, and documents the model supports.
* **Streaming**: show an answer as the model writes it.
* **Structured output**: answers you read as a Hash through `response.parsed`.
* **Tools**: Ruby classes the model calls, with an optional approval step before they run.
* **MCP servers**, **skills**, and **code execution**: tools from a [Model Context Protocol server]({% link _tools/mcp.md %}), folders of instructions in the [Agent Skills]({% link _tools/skills.md %}) format, and [code the model runs in a sandbox]({% link _advanced/code-execution.md %}).
* **File stores**: an agent's own files, in Active Storage or a folder on disk, which also keep attachments and long tool results out of the conversation. The model finds, reads, searches, and edits them with tools. See [File Stores]({% link _core_features/file-stores.md %}).
* **Agents**: a model, instructions, and tools in a reusable class.
* **Loop control**: run the model and the tools one step at a time.

An agent is a configured chat with a name:

```ruby
class SupportAgent < RubyLLM::Agent
  model "{{ site.models.default_chat }}"
  instructions "You answer customers of Acme Outfitters. Be brief and friendly."
  tools SearchDocs
end

SupportAgent.new.ask "How do I return a jacket that doesn't fit?"
```

Coordinate agents with ordinary Ruby methods and jobs. [Agentic Workflows]({% link _advanced/agentic-workflows.md %}) shows routing, chaining, and parallel work; [Durable Agents]({% link _advanced/durable-agents-overview.md %}) shows agents that resume across jobs and deploys.

## Individual AI Operations

Some work needs no conversation. An operation takes an input and returns a typed result:

```ruby
transcript = RubyLLM.transcribe "voicemail.mp3"
transcript.text
```

The support desk uses most of them:

| Operation | Support desk use | Result |
| --- | --- | --- |
| [`transcribe`]({% link _getting_started/audio-transcription.md %}) | Turn a voicemail into text | `transcription.text` |
| [`ocr`]({% link _getting_started/ocr.md %}) | Read a scanned invoice | `document.markdown` |
| [`moderate`]({% link _getting_started/moderation.md %}) | Check a message before anyone reads it | `moderation.flagged?` |
| [`embed`]({% link _getting_started/embeddings.md %}) | Turn FAQ answers into vectors for search | `embedding.vectors` |
| [`rerank`]({% link _getting_started/rerank.md %}) | Put the best search hit first | `ranked.results` |
| [`judge`]({% link _advanced/judgments.md %}) | Ask a typed question, such as "is this reply polite?" | probabilities, choices, and scores |
| [`paint`]({% link _getting_started/image-generation.md %}) | Illustrate a help article | `image.save(path)` |
| [`animate`]({% link _advanced/video-generation.md %}) | Make a packing how-to clip | `video.save(path)` |
| [`speak`]({% link _getting_started/text-to-speech.md %}) | Read a reply aloud on the phone line | `speech.save(path)` |

An operation may take several requests. `animate` submits a job and waits for the video, while `animate_later` returns a `VideoJob` at once. Transcription can stream. You call the operation the same way, and RubyLLM handles the lifecycle.

## Providers

A provider is the service you talk to, such as OpenAI, Anthropic, Gemini, Bedrock, or a local Ollama. It knows the service's URL, authentication, settings, and models, and picks a protocol, the request format the service speaks. Your code never deals with either: the same `ask` works on every provider, and switching is a different model name. To pick the protocol yourself, see [Choosing the Wire Protocol]({% link _core_features/chat-request-control.md %}#choosing-the-wire-protocol). To connect a service RubyLLM doesn't know yet, see [Custom Providers and Protocols]({% link _reference/custom-providers.md %}).

## What Everything Shares

### Models

The [Model Registry]({% link _reference/models.md %}) records which providers offer each model, with its capabilities, limits, and prices. RubyLLM uses it to find the provider for a model name:

```ruby
chat = RubyLLM.chat(model: "{{ site.models.default_chat }}")
chat.model.provider
# => "openai"

RubyLLM.models.find("{{ site.models.default_chat }}").supports?(:vision)
# => true
```

Pass `provider:` to choose the service yourself. [Model Resolution]({% link _reference/model-resolution.md %}) explains aliases and how RubyLLM chooses when several providers offer a model, and the [Models]({% link _reference/available-models.md %}) page lists them all.

### Configuration

`RubyLLM.configure` sets keys and defaults for the whole application. A context holds a separate set, such as one tenant's key, and has the same entry points: `chat`, `paint`, `embed`, and the rest.

```ruby
context = RubyLLM.context do |config|
  config.openai_api_key = store.openai_api_key
end

context.chat.ask "Do you ship to Canada?"
```

Per-conversation options use chainable methods such as `with_instructions` and `with_tools`. See [Configuration]({% link _getting_started/configuration.md %}).

### Usage, Costs, and Instrumentation

Every result knows its tokens and cost:

```ruby
response = chat.ask "Summarize our returns policy in one sentence."
response.tokens.output
response.cost.total
chat.cost.total
```

A response's cost covers every attempt the provider billed for it, so a successful answer includes the cost of retries before it. A turn with tool calls has several responses, and `chat.cost` adds up the whole conversation. Unknown costs stay `nil`. In Rails, a usage ledger records each attempt. See [Cost and Usage Tracking]({% link _core_features/cost-and-usage-tracking.md %}).

[Instrumentation]({% link _advanced/instrumentation.md %}) reports every call, from chats, tools, and individual operations, and `RubyLLM.workflow` groups calls into a named unit. [OpenTelemetry]({% link _advanced/opentelemetry.md %}) sends them to your tracing backend, and [Evaluations]({% link _advanced/evaluations.md %}) grade your agents' answers against a dataset of cases.

### Background Work and Provider Resources

* [Batches]({% link _advanced/batches.md %}) send many chats or embeddings for the provider to process later, at a lower price.
* [File Storage]({% link _core_features/files.md %}) uploads files to a provider and downloads its results with `RubyLLM.upload` and `RubyLLM.download`.
* [Prompt Caching]({% link _core_features/prompt-caching.md %}) reuses long, stable prompts, including caches you create with `RubyLLM.cache`.
* [Error Handling]({% link _advanced/error-handling.md %}) covers RubyLLM's errors, automatic retries, and model fallbacks.

## Rails Integration

In Rails, your own Active Record models become chats and messages. `acts_as_chat` and `acts_as_message` give them the same methods as the plain-Ruby objects:

```ruby
class Chat < ApplicationRecord
  acts_as_chat
  belongs_to :customer
end

class Message < ApplicationRecord
  acts_as_message
end

chat = Chat.create!(customer: current_customer, model: "{{ site.models.default_chat }}")
chat.ask "Where is my order R-1042?"
```

Your application owns its chats and messages, with their customers, permissions, and anything else you add. RubyLLM owns eight supporting tables: the model registry, tool calls, usage, queued messages, chat files, batches, MCP credentials, and provider files. It can change them between releases without touching your models.

Rails integration adds:

* [Active Record persistence]({% link _advanced/rails-persistence.md %}): reload conversations, restore agents, and read usage through associations.
* [Active Storage attachments]({% link _core_features/attachments.md %}): pass an attachment with `with:`, as you pass a file in plain Ruby.
* [Hotwire streaming]({% link _advanced/rails-streaming.md %}): stream replies into a page.
* [Active Job]({% link _advanced/durable-agents.md %}): run agents in your job backend, and resume them in another process.
* [Generators]({% link _advanced/rails-generators.md %}): persistence, agents, tools, schemas, and a chat UI in conventional directories.

Individual operations work in Rails services and jobs as they do anywhere. See [Rails Integration]({% link _getting_started/rails.md %}).

## Next Steps

Read the rest of Start Here in order: [Chat]({% link _getting_started/chat.md %}), [Tools]({% link _getting_started/tools.md %}), [Agents]({% link _getting_started/agents.md %}), [Configuration]({% link _getting_started/configuration.md %}), the individual operations, and [Rails Integration]({% link _getting_started/rails.md %}). Then follow the guide for the feature you're building.

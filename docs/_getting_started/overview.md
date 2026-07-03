---
layout: default
title: How RubyLLM Works
nav_order: 2
description: Understand how RubyLLM works and how its components fit together
redirect_from:
  - /guides/overview
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

* How RubyLLM provides a unified interface to multiple AI providers
* The core components and how they work together
* The design principles that guide the framework
* How providers are implemented and extended
* The role of configuration in managing complexity

## Core Components

RubyLLM consists of several core components that work together to provide its functionality. Understanding these components will help you use the framework more effectively.

### Chat

The Chat component is the primary interface for conversational AI. When you create a chat instance with `RubyLLM.chat`, you're creating an object that manages a conversation with an AI model.

```ruby
chat = RubyLLM.chat(model: "{{ site.models.default_chat }}")
```

The chat object maintains conversation history, handles message formatting for the specific provider, and manages the request/response cycle. Each provider implements its own chat adapter that translates between RubyLLM's unified format and the provider's specific API requirements.

### Messages

Messages are the fundamental unit of conversation in RubyLLM. Each message has a role (user, assistant, system, or tool) and content (text, images, or other data). The framework automatically manages message history and formatting.

```ruby
response = chat.ask("What is Ruby?")
```

Messages can include various types of content depending on the model's capabilities. Vision-capable models can process images, while some models support audio or document analysis.

### Tools

Tools allow AI models to call Ruby code during conversations. This powerful feature enables AI assistants to perform calculations, fetch data, or interact with external systems.

```ruby
class Calculator < RubyLLM::Tool
  desc "Performs basic arithmetic"

  def execute(expression:)
    { result: eval(expression) }
  end
end
```

When you provide tools to a chat, the AI model can decide when to use them based on the conversation context. The framework handles the complexity of tool calling protocols across different providers.

### Providers

A provider answers two questions about an AI service: *where* to talk and *who* you are. It holds the host (`api_base`), the authentication headers, the configuration options the service needs, and its model catalog. Built-in providers include OpenAI, Anthropic, Gemini, Bedrock, and over a dozen others, plus OpenAI-compatible providers like Ollama and Perplexity.

A provider does *not* contain wire-format logic. It declares which protocol (or protocols) it speaks and, when a service exposes several APIs, routes each model to the right one. Swapping in a new host and auth - the way Ollama reuses the Chat Completions wire format against a local server - is a provider concern, not a protocol concern.

### Protocols

A protocol knows *how* to talk to a family of APIs: rendering request payloads, parsing responses, streaming chunks, and naming the endpoints involved. Protocols live under `RubyLLM::Protocols` (for example `RubyLLM::Protocols::ChatCompletions`, `RubyLLM::Protocols::Anthropic`, `RubyLLM::Protocols::Gemini`), and each is a subclass of `RubyLLM::Protocol`.

Splitting providers from protocols is what lets one wire format serve many hosts and one host serve many wire formats. The OpenAI Chat Completions dialect is reused by Ollama, Perplexity, DeepSeek, and others, each pairing it with its own host and auth. Conversely, Vertex AI is a single provider that speaks four protocols - Gemini, Anthropic, Mistral, and Chat Completions - choosing one per model. You can add a provider without writing a protocol (when it speaks an existing wire format) or add a protocol without writing a provider (when a new dialect rides on an existing host).

### Configuration

Configuration in RubyLLM works at three levels: global defaults, isolated contexts for multi-tenancy, and instance-specific settings.

```ruby
RubyLLM.configure do |config|
  config.openai_api_key = ENV["OPENAI_API_KEY"]
  config.default_model = "{{ site.models.default_chat }}"
end

context = RubyLLM.context do |config|
  config.openai_api_key = tenant.api_key  # Different credentials
  config.default_model = "{{ site.models.openai_tools }}"         # Different defaults
end
chat = context.chat  # Uses context configuration

chat = RubyLLM.chat(model: "{{ site.models.anthropic_opus }}", temperature: 0.7)
```

This layered approach supports everything from simple scripts to complex multi-tenant applications.

## Design Principles

RubyLLM follows several key design principles that shape its architecture and API design.

### Provider Agnostic

The framework treats all AI providers equally. Whether you're using OpenAI, Anthropic, or a local model through Ollama, the code looks the same. This principle extends to all features - chat, embeddings, image generation, and tools all work consistently across providers.

### Progressive Disclosure

Simple things should be simple, and complex things should be possible. Basic chat requires just one line of code, but the framework supports advanced features like streaming, tool calling, and structured output when you need them.

```ruby
response = RubyLLM.chat.ask("Hello")

chat = RubyLLM.chat(model: "{{ site.models.default_chat }}", temperature: 0.2)
  .with_instructions("You are a helpful assistant")
  .with_tool(DatabaseQuery)
  .with_schema(ResponseFormat)
```

### Ruby Conventions

The framework follows Ruby idioms and conventions. Method names are descriptive, configuration uses blocks, and the API feels natural to Ruby developers. This extends to error handling, where provider-specific errors are wrapped in consistent RubyLLM exceptions.

### Minimal Dependencies

RubyLLM depends only on essential gems: Faraday for HTTP, Zeitwerk for autoloading, and Marcel for file type detection. This keeps the framework lightweight and reduces potential conflicts in your application.

## How Providers Work

Understanding how providers and protocols fit together helps you make better use of RubyLLM and create your own.

A **provider** (`RubyLLM::Provider`) knows where to talk and who it is: its host (`api_base`), its authentication `headers`, its `configuration_options`, and its model catalog. A **protocol** (`RubyLLM::Protocol`) knows how to talk: rendering payloads, parsing responses, and streaming chunks for a family of APIs. A provider declares the protocols it speaks and selects one per request.

### Provider Detection

When you specify a model, RubyLLM determines which provider to use. The framework maintains a registry of known models and their providers, but you can also specify a provider explicitly or use custom endpoints.

```ruby
chat = RubyLLM.chat(model: "{{ site.models.default_chat }}")  # Uses OpenAI

chat = RubyLLM.chat(
  model: "{{ site.models.local_llama }}",
  provider: :ollama,
)
```

### Protocol Selection

Some services expose more than one API. A provider registers each protocol under a name with the `protocol` macro and routes each model to the right one through the `protocol_for` hook. OpenAI registers both `:responses` and `:chat_completions`, defaulting to Responses but sending audio, realtime, and search-preview models to Chat Completions. Vertex AI registers four protocols and routes by model ID.

You can force a specific protocol per chat with `with_protocol`, or globally with the `<provider>_protocol` configuration option that every provider exposes:

```ruby
RubyLLM.configure do |config|
  config.openai_protocol = :chat_completions
end
```

### Capability Management

Different models have different capabilities. Some support vision, others support tool calling, and some have specific context window sizes. RubyLLM tracks these capabilities and helps you use models appropriately.

```ruby
model_info = RubyLLM.models.find("{{ site.models.openai_tools }}")
model_info.capabilities       # => ["function_calling", "streaming", "vision", "structured_output", ...]
model_info.supports_vision?   # => true
model_info.function_calling?  # => true
```

### Response Normalization

Each protocol parses its service's responses into the same `RubyLLM::Message` and `RubyLLM::Chunk` objects, so your code doesn't need to handle provider-specific differences.

You can add support for a new service yourself. The [Custom Providers and Protocols]({% link _reference/custom-providers.md %}) guide walks through implementing a protocol and a provider and shipping them as a gem.

## Rails Integration

RubyLLM integrates deeply with Rails through ActiveRecord mixins and generators. The `acts_as_chat` and `acts_as_message` methods add AI capabilities to your models while following Rails conventions.

```ruby
class Conversation < ApplicationRecord
  acts_as_chat
end

conversation = Conversation.create!(model: "{{ site.models.default_chat }}")
response = conversation.ask("How can I help you today?")
```

The Rails integration handles persistence, associations, and even real-time updates through Action Cable, making it easy to build AI-powered Rails applications.

## Next Steps

Now that you understand how RubyLLM works, you're ready to dive deeper into specific features. We recommend following this learning path:

1. Complete the [Getting Started]({% link _getting_started/getting-started.md %}) guide if you haven't already
2. Learn about [Chatting with AI Models]({% link _core_features/chat.md %}) for conversational features
3. Explore [Tools and Function Calling]({% link _core_features/tools.md %}) to give AI access to your code
4. For Rails developers, the [Rails Integration]({% link _advanced/rails.md %}) guide covers database persistence and real-time features

Each guide builds on the concepts introduced here, gradually revealing more advanced features as you need them.

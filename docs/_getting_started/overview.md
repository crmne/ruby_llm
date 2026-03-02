---
layout: default
title: Overview
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
# Creates a user message, sends it, and returns an assistant message
```

Messages can include various types of content depending on the model's capabilities. Vision-capable models can process images, while some models support audio or document analysis.

### Tools

Tools allow AI models to call Ruby code during conversations. This powerful feature enables AI assistants to perform calculations, fetch data, or interact with external systems.

```ruby
class Calculator < RubyLLM::Tool
  description "Performs basic arithmetic"
  param :expression, desc: "Mathematical expression to evaluate"

  def execute(expression:)
    { result: eval(expression) }
  end
end
```

When you provide tools to a chat, the AI model can decide when to use them based on the conversation context. The framework handles the complexity of tool calling protocols across different providers.

### Providers

Providers are the adapters that connect RubyLLM to specific AI services. Each provider implements the same interface but handles the unique requirements of its service - authentication, request formatting, response parsing, and streaming protocols.

The provider system allows RubyLLM to support many different AI services while maintaining a consistent interface. Whether you're using OpenAI, Anthropic, or a local model, your code stays the same. New providers can be added without changing the core framework.

### Configuration

Configuration in RubyLLM works at three levels: global defaults, isolated contexts for multi-tenancy, and instance-specific settings.

```ruby
# Global configuration - applies everywhere
RubyLLM.configure do |config|
  config.openai_api_key = ENV["OPENAI_API_KEY"]
  config.default_model = "{{ site.models.default_chat }}"
end

# Context configuration - isolated scope
context = RubyLLM.context do |config|
  config.openai_api_key = tenant.api_key  # Different credentials
  config.default_model = "{{ site.models.openai_tools }}"         # Different defaults
end
chat = context.chat  # Uses context configuration

# Instance configuration - what you need right now
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
# Simple
response = RubyLLM.chat.ask("Hello")

# Advanced
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

Understanding how providers work helps you make better use of RubyLLM and even create custom providers if needed.

### Provider Detection

When you specify a model, RubyLLM automatically determines which provider to use. The framework maintains a registry of known models and their providers, but you can also explicitly specify providers or use custom endpoints.

```ruby
# Automatic detection
chat = RubyLLM.chat(model: "{{ site.models.default_chat }}")  # Uses OpenAI

# Explicit provider
chat = RubyLLM.chat(
  model: "{{ site.models.local_llama }}",
  provider: :ollama,
)
```

### Capability Management

Different models have different capabilities. Some support vision, others support tool calling, and some have specific context window sizes. RubyLLM tracks these capabilities and helps you use models appropriately.

```ruby
model_info = RubyLLM.models.find("{{ site.models.openai_tools }}")
puts model_info.capabilities
# => [:chat, :vision, :tools, :json_mode]
```

### Response Normalization

Each provider returns responses in different formats. RubyLLM normalizes these into consistent response objects, so your code doesn't need to handle provider-specific differences.

## Rails Integration

RubyLLM integrates deeply with Rails through ActiveRecord mixins and generators. The `acts_as_chat` and `acts_as_message` methods add AI capabilities to your models while following Rails conventions.

```ruby
class Conversation < ApplicationRecord
  acts_as_chat
end

# Now your model can interact with AI
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

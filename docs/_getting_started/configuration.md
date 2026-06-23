---
layout: default
title: Configuration
nav_order: 3
has_children: true
description: Configure once, use everywhere. API keys, defaults, timeouts, and multi-tenant contexts made simple.
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

* How to configure API keys for the providers you use.
* How to set default models for chat, embeddings, and images.
* How to wire RubyLLM into a Rails initializer.
* Where to find provider, connection, and reference details.

## Quick Start

The simplest configuration just sets your API keys:

```ruby
RubyLLM.configure do |config|
  config.openai_api_key = ENV['OPENAI_API_KEY']
  config.anthropic_api_key = ENV['ANTHROPIC_API_KEY']
end
```

That's it. RubyLLM uses sensible defaults for everything else.

## API Keys

Configure API keys only for the providers you use. RubyLLM won't complain about missing keys for providers you never touch.

```ruby
RubyLLM.configure do |config|
  config.openai_api_key = ENV['OPENAI_API_KEY']
  config.anthropic_api_key = ENV['ANTHROPIC_API_KEY']
  config.gemini_api_key = ENV['GEMINI_API_KEY']
end
```

Each provider has its own key (and sometimes region or project settings). For the full list of providers, organization headers, Vertex AI authentication, and OpenAI-compatible custom endpoints, see [Provider Setup and Custom Endpoints]({% link _getting_started/configuration-providers.md %}).

> Attempting to use an unconfigured provider will raise `RubyLLM::ConfigurationError`. Only configure what you need.
{: .note }

## Default Models

Set defaults for the convenience methods (`RubyLLM.chat`, `RubyLLM.embed`, `RubyLLM.paint`):

```ruby
RubyLLM.configure do |config|
  config.default_model = '{{ site.models.anthropic_current }}'           # For RubyLLM.chat
  config.default_embedding_model = '{{ site.models.embedding_large }}'  # For RubyLLM.embed
  config.default_image_model = 'dall-e-3'              # For RubyLLM.paint
  config.default_speech_model = '{{ site.models.default_speech }}'       # For RubyLLM.speak
end
```

Defaults if not configured:
- Chat: `{{ site.models.default_chat }}`
- Embeddings: `{{ site.models.default_embedding }}`
- Images: `{{ site.models.default_image }}`
- Speech: `{{ site.models.default_speech }}`

## Rails Integration

For Rails applications, create an initializer:

```ruby
# config/initializers/ruby_llm.rb
RubyLLM.configure do |config|
  config.openai_api_key = Rails.application.credentials.openai_api_key
  config.anthropic_api_key = Rails.application.credentials.anthropic_api_key
  config.anthropic_api_base = ENV['ANTHROPIC_API_BASE'] # Available in v1.13.0+ (optional custom Anthropic endpoint)
  config.ollama_api_key = ENV['OLLAMA_API_KEY'] # Available in v1.13.0+ (optional for remote/authenticated Ollama)

  config.logger = Rails.logger

  config.request_timeout = Rails.env.production? ? 120 : 30
  config.log_level = Rails.env.production? ? :info : :debug
end
```

## Next Steps

- [Provider Setup and Custom Endpoints]({% link _getting_started/configuration-providers.md %}) - every provider's keys, OpenAI organization headers, Vertex AI auth, and OpenAI-compatible endpoints.
- [Connection, Logging and Contexts]({% link _getting_started/configuration-connection.md %}) - timeouts, retries, proxies, debug logging, the model registry file, and isolated per-tenant contexts.
- [Configuration Reference]({% link _getting_started/configuration-reference.md %}) - the complete option list in one block.
- [Start chatting with AI models]({% link _core_features/chat.md %}) - put your configuration to work.
- [Set up Rails integration]({% link _advanced/rails.md %}) - persistence, streaming, and generators.

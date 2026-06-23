---
layout: default
title: Custom Providers and Protocols
nav_order: 3
description: Teach RubyLLM to talk to a new AI service by writing a provider, a protocol, or both, and ship it as a gem.
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

* How RubyLLM splits a **provider** (host, auth, catalog) from a **protocol** (wire format).
* How to add a provider for a service that speaks an API RubyLLM already knows.
* How to write a protocol for a new wire format or dialect.
* How to register your provider with `RubyLLM::Provider.register` and expose its configuration.
* How to package a provider and protocol as a gem that people add to RubyLLM.

## The Provider/Protocol Split

RubyLLM separates two concerns that other libraries tangle together. A **provider** knows *where* to talk and *who* you are: its host, its authentication headers, the configuration it needs, and its model catalog. A **protocol** knows *how* to talk to a family of APIs: rendering request payloads, parsing responses, streaming chunks, and naming the endpoints involved.

```ruby
# lib/ruby_llm/protocol.rb
# A protocol knows how to talk to a family of APIs: rendering payloads,
# parsing responses, streaming chunks, and the endpoints involved.
# Providers know where to talk and who they are.
```

This split is the whole reason RubyLLM scales across services. One wire format serves many hosts - the OpenAI Chat Completions dialect is reused by Ollama, Perplexity, and DeepSeek, each with its own host and auth. One host can serve many wire formats - Vertex AI is a single provider that speaks Gemini, Anthropic, Mistral, and Chat Completions, picking one per model.

So before you write anything, decide which case you are in:

* **The service speaks an API RubyLLM already knows** (almost always OpenAI Chat Completions). Write only a provider. This is the common case, and it is a few dozen lines.
* **The service speaks a new wire format or a dialect that differs in payload or parsing.** Write a protocol (or a thin subclass of an existing one) and a provider that declares it.

We will build a fictional provider, `Acme`, that exposes an OpenAI-compatible Chat Completions API at `https://api.acme.ai/v1`, then show how to override the wire format when a dialect diverges.

## Adding a Provider

A provider is a subclass of `RubyLLM::Provider`. The base class raises `NotImplementedError` from `api_base`, so that method is the one thing you must define; everything else has a sensible default you override as needed.

Here is a complete, working provider for an OpenAI-compatible service. It declares the existing Chat Completions protocol, points at a host, supplies auth, and lists its configuration:

```ruby
# lib/ruby_llm/providers/acme.rb
module RubyLLM
  module Providers
    class Acme < Provider
      # Acme's dialect of the Chat Completions API.
      class ChatCompletions < Protocols::ChatCompletions
      end

      protocol :chat_completions, ChatCompletions

      def api_base
        @config.acme_api_base || 'https://api.acme.ai/v1'
      end

      def headers
        { 'Authorization' => "Bearer #{@config.acme_api_key}" }
      end

      class << self
        def capabilities
          Acme::Capabilities
        end

        def configuration_options
          %i[acme_api_key acme_api_base]
        end

        def configuration_requirements
          %i[acme_api_key]
        end
      end
    end
  end
end
```

That is the real shape of a RubyLLM provider - DeepSeek, Perplexity, and Mistral are all variations on it. Each piece earns its place:

* **`protocol :chat_completions, ChatCompletions`** registers a named protocol. The first protocol you declare becomes the provider's default. Here you subclass the built-in `Protocols::ChatCompletions` so you can later override wire-format seams; if the service is a perfect match you can register `Protocols::ChatCompletions` directly.
* **`api_base`** is the host. RubyLLM hands it straight to Faraday, so a relative endpoint path like `chat/completions` is resolved against it. Reading `@config.acme_api_base` first lets users point at a proxy or self-hosted instance, with a default for the public API.
* **`headers`** supplies authentication. The base returns `{}`, so this is optional - but nearly every remote service needs it. The hash is merged into every request.
* **`configuration_options`** lists the config keys your provider contributes. **`configuration_requirements`** is the subset that must be present before the provider is usable.
* **`capabilities`** returns a module of provider-level capability checks (context windows, pricing, supported features). Used for unlisted models and registry fallbacks.

`@config` is a `RubyLLM::Configuration` instance, and `@config.acme_api_key` works only because you listed `acme_api_key` in `configuration_options` - registering the provider materializes those accessors. We will register it below.

### Provider-Level Capabilities

`capabilities` returns a module whose methods answer questions about a model when the registry can't. Model it on the built-in providers - a `module_function` module with predicate and lookup methods:

```ruby
# lib/ruby_llm/providers/acme/capabilities.rb
module RubyLLM
  module Providers
    class Acme
      # Provider-level capability checks used outside the model registry.
      module Capabilities
        module_function

        def context_window_for(_model_id)
          128_000
        end

        def max_tokens_for(_model_id)
          16_384
        end

        def supports_tool_choice?(_model_id)
          true
        end
      end
    end
  end
end
```

### Reusing a Wire Format Against a Different Host

The empty `Acme::ChatCompletions < Protocols::ChatCompletions` above is not a placeholder - it is the entire point of the split. Because `Protocols::ChatCompletions` builds requests against *relative* paths (`completion_url` returns `'chat/completions'`), swapping `api_base` and `headers` is all it takes to retarget the same payload-rendering and response-parsing logic at a new server. This is exactly how Ollama runs the OpenAI dialect against a local host:

```ruby
# lib/ruby_llm/providers/ollama.rb
class Ollama < Provider
  class ChatCompletions < Protocols::ChatCompletions
    include Ollama::Chat
    include Ollama::Media
    include Ollama::Models
  end

  protocol :chat_completions, ChatCompletions

  def api_base
    @config.ollama_api_base
  end

  def headers
    return {} unless @config.ollama_api_key

    { 'Authorization' => "Bearer #{@config.ollama_api_key}" }
  end
end
```

Ollama mixes in a few small modules to adjust its dialect. That is the bridge to writing a protocol.

## Writing a Protocol

When a service's payloads, response shapes, or endpoints differ from anything RubyLLM ships, you write a protocol. A protocol is a subclass of `RubyLLM::Protocol`, but you rarely fill it in from scratch: the base class defines the orchestration - `complete` renders a payload then dispatches to `sync_response` or `stream_response` - and calls out to a set of seam methods that you supply.

For the Chat Completions family, the seams you override most often are:

| Seam | Responsibility |
|------|----------------|
| `completion_url` | The (relative) endpoint path for completions |
| `stream_url` | The streaming endpoint (defaults to `completion_url`) |
| `render_payload` | Build the request body from messages, tools, temperature, etc. |
| `parse_completion_response` | Turn a response into a `RubyLLM::Message` |
| `build_chunk` | Turn one SSE event into a `RubyLLM::Chunk` |
| `format_role` / `format_content` | Shape a message's role and content |

The smallest real dialect changes only message shaping. DeepSeek, for example, overrides just `format_role` and `format_content` to disable attachments its API rejects:

```ruby
# lib/ruby_llm/providers/deepseek/chat.rb
module RubyLLM
  module Providers
    class DeepSeek
      module Chat
        module_function

        def format_role(role)
          role.to_s
        end

        def format_content(content)
          Protocols::ChatCompletions::Media.format_content(
            content,
            document_attachments: :none,
            image_attachments: false,
            audio_attachments: false
          )
        end
      end
    end
  end
end
```

You then mix that module into the provider's protocol subclass:

```ruby
# lib/ruby_llm/providers/acme.rb (excerpt)
class ChatCompletions < Protocols::ChatCompletions
  include Acme::Chat
end
```

If Acme exposes completions at a non-standard path, override the endpoint seam in the same module:

```ruby
# lib/ruby_llm/providers/acme/chat.rb (excerpt)
module Chat
  def completion_url
    'v2/chat'
  end
end
```

For a genuinely new wire format (not a Chat Completions variant), subclass `RubyLLM::Protocol` directly and implement the seams the base operations call - `render_payload`, `completion_url`, `parse_completion_response`, and, for streaming, `stream_url` and `build_chunk`. Study `RubyLLM::Protocols::Anthropic` and `RubyLLM::Protocols::Gemini` as worked examples of non-OpenAI dialects.

> A protocol instance is constructed against a live provider with `protocol_class.new(provider, model)`. Inside a protocol you have `provider`, `config`, `connection`, and `model` available - the protocol borrows the provider's Faraday connection, so you never build HTTP yourself.
{: .note }

### Declaring Multiple Protocols

When one service speaks several APIs, register each under a name and override `protocol_for` to route per model. The base hook returns the default protocol; you narrow it:

```ruby
# lib/ruby_llm/providers/openai.rb (excerpt)
protocol :responses, Protocols::Responses, batches: Protocols::Responses::Batches
protocol :chat_completions, Protocols::ChatCompletions, batches: Protocols::ChatCompletions::Batches
files Protocols::OpenAI::Files

# Audio, realtime, and search-preview models only exist on Chat Completions.
def protocol_for(model, **)
  model.id.match?(/audio|realtime|search-preview/) ? protocols[:chat_completions] : super
end
```

Selection follows a fixed precedence at request time: an explicit `with_protocol` (or `protocol:` argument) wins, then the `<provider>_protocol` configuration option, then your `protocol_for` hook. Because `register` adds an `acme_protocol` config option automatically, a user can override your routing globally:

```ruby
RubyLLM.configure do |config|
  config.acme_protocol = :chat_completions
end
```

The optional `batches:` argument to `protocol` and the `files` macro wire up the batch and file-upload APIs; reach for them only once the basics work.

## Registering the Provider

A provider does nothing until it is registered. `RubyLLM::Provider.register` stamps the provider's slug, inserts it into the global registry, and materializes its configuration accessors:

```ruby
# lib/ruby_llm/provider.rb
def register(name, provider_class)
  provider_class.slug = name.to_s
  providers[name.to_sym] = provider_class
  RubyLLM::Configuration.register_provider_options(provider_class.configuration_options + [:"#{name}_protocol"])
end
```

Register Acme after its classes are loaded:

```ruby
RubyLLM::Provider.register :acme, RubyLLM::Providers::Acme
```

That one call does three things: it sets `Acme.slug` to `"acme"` (which is how `@config.acme_api_key` and `@config.acme_protocol` resolve), adds the class to `RubyLLM::Provider.providers`, and defines a config accessor for every option in `configuration_options` plus the synthetic `acme_protocol`. After registering, your provider is a first-class citizen:

```ruby
RubyLLM.configure do |config|
  config.acme_api_key = ENV['ACME_API_KEY']
end

chat = RubyLLM.chat(model: 'acme-large', provider: :acme, assume_model_exists: true)
chat.ask('Hello from a custom provider!')
```

Pass `assume_model_exists: true` for models that aren't in the registry, or have your protocol's `list_models` populate the catalog from the service's models endpoint.

> The slug RubyLLM uses everywhere comes from the symbol you pass to `register`, not from the class name. Register as `:acme` and your config keys are `acme_api_key`, `acme_api_base`, and `acme_protocol`. Keep the symbol, the `configuration_options` prefix, and the keys you read off `@config` in agreement, or configuration silently returns `nil`.
{: .warning }

## Packaging as a Gem

To ship your provider so others can add it to RubyLLM, package these files in a gem that depends on `ruby_llm`. Lay the files out under `lib/ruby_llm/providers/` mirroring the built-in providers:

```
ruby_llm-acme/
├── lib/
│   ├── ruby_llm-acme.rb
│   └── ruby_llm/
│       └── providers/
│           ├── acme.rb
│           └── acme/
│               ├── capabilities.rb
│               └── chat.rb
└── ruby_llm-acme.gemspec
```

RubyLLM's own autoloader (`Zeitwerk::Loader.for_gem`) is scoped to the RubyLLM gem and will not discover files in your gem. Load your own files and call `register` from your gem's entry point:

```ruby
# lib/ruby_llm-acme.rb
require 'ruby_llm'

require_relative 'ruby_llm/providers/acme/capabilities'
require_relative 'ruby_llm/providers/acme/chat'
require_relative 'ruby_llm/providers/acme'

RubyLLM::Provider.register :acme, RubyLLM::Providers::Acme
```

Now anyone who adds your gem and requires it gets a fully wired provider:

```ruby
require 'ruby_llm-acme'

RubyLLM.configure { |config| config.acme_api_key = ENV['ACME_API_KEY'] }
RubyLLM.chat(model: 'acme-large', provider: :acme, assume_model_exists: true).ask('Hi')
```

> If your provider uses an acronym or mixed-case constant (like `OpenAI` or `XAI`), Zeitwerk needs an inflection rule to map the file name to the constant. With explicit `require_relative` calls as shown, you sidestep autoloading entirely and avoid the inflection setup.
{: .note }

## What's Next?

You can now teach RubyLLM to speak to any AI service, whether it reuses an existing wire format or needs a brand-new one. From here:

* [How RubyLLM Works]({% link _getting_started/overview.md %}) - see where providers and protocols sit among the framework's components.
* [Provider Setup and Custom Endpoints]({% link _getting_started/configuration-providers.md %}) - configure built-in providers and OpenAI-compatible endpoints.
* [RubyLLM Ecosystem]({% link _reference/ecosystem.md %}) - list your provider gem alongside other community extensions.
---
layout: default
title: Protocols
nav_order: 7
description: Providers say where to talk. Protocols say how. Route models to the wire protocol they need.
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

## Providers and Protocols

RubyLLM separates two ideas that usually get tangled together:

* A **provider** knows *where* to talk and *who you are*: the host, the authentication, the model catalog, and the configuration. `:openai`, `:vertexai`, and `:bedrock` are providers.
* A **protocol** knows *how* to talk: how to render payloads, parse responses, stream chunks, and which endpoints to hit. `Protocols::ChatCompletions`, `Protocols::Responses`, `Protocols::Anthropic`, `Protocols::Gemini`, and `Protocols::Converse` are protocols.

One provider can speak several protocols. OpenAI exposes both the Responses API and the Chat Completions API. Vertex AI hosts Google models behind the Gemini API and Claude models behind Anthropic's — same host, same auth, different wire formats.

You normally never see any of this. `RubyLLM.chat` works exactly as before:

```ruby
chat = RubyLLM.chat(model: 'gpt-5.4')
chat.ask "What's the best way to learn Ruby?"
```

## How requests get routed

Each provider declares the protocols it speaks and picks one per request:

1. An explicit `with_protocol` on the chat wins.
2. Otherwise an app-wide `config.<provider>_protocol` wins.
3. Otherwise the provider routes by model and request — OpenAI sends audio models to Chat Completions and everything else to Responses; Vertex AI sends `claude-*` models to the Anthropic protocol and the rest to Gemini.
4. Otherwise the provider's default protocol applies.

## Overriding the protocol

Per chat:

```ruby
chat = RubyLLM.chat(model: 'gpt-5.4').with_protocol(:chat_completions)
```

App-wide:

```ruby
RubyLLM.configure do |config|
  config.openai_protocol = :chat_completions
end
```

Unknown protocol names raise immediately, listing what the provider speaks.

{: .note }
OpenAI defaults to the Responses API, which is the only endpoint supporting reasoning models with tools and extended thinking together. Switch back to `:chat_completions` if you depend on Chat Completions quirks.

## Writing a protocol

A protocol subclasses `RubyLLM::Protocol` (or an existing protocol, to tweak a dialect) and gets the provider's config and connection. Provider-specific dialects live as small subclasses inside the provider:

```ruby
module RubyLLM
  module Providers
    class Mistral < Provider
      class ChatCompletions < Protocols::ChatCompletions
        def render_payload(...)
          payload = super
          payload.delete(:stream_options)
          payload
        end
      end

      protocol :chat_completions, ChatCompletions
    end
  end
end
```

The first declared protocol is the provider's default. To route dynamically, override `protocol_for`:

```ruby
class VertexAI < Provider
  protocol :gemini, VertexAI::Gemini
  protocol :anthropic, VertexAI::Anthropic

  def protocol_for(model, **)
    model.id.start_with?('claude') ? protocols[:anthropic] : super
  end
end
```

`protocol_for` also receives the request context (`tools:`, `thinking:`, `schema:`), so routing can depend on feature combinations, not just model ids.

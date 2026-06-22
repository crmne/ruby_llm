---
layout: default
title: Advanced Request Control
parent: "Chat"
nav_order: 6
description: Reach provider-specific features with custom parameters, wire protocols, raw content blocks, and HTTP headers
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

* How to pass provider-specific parameters with `with_params`.
* How to choose the wire protocol a provider speaks.
* How to send a raw content payload with `Content::Raw`.
* How to use Anthropic prompt caching to reduce costs.
* How to add custom HTTP headers to a request.

## Provider-Specific Parameters

Different providers offer unique features and parameters. The `with_params` method lets you access these provider-specific capabilities while maintaining RubyLLM's unified interface. Parameters passed via `with_params` will override any defaults set by RubyLLM, giving you full control over the API request payload.

```ruby
# JSON object mode on the Responses API (OpenAI's default protocol)
chat = RubyLLM.chat.with_params(text: { format: { type: 'json_object' } })
response = chat.ask "What is the square root of 64? Answer with a JSON object with the key `result`."
puts JSON.parse(response.content)

# The same option on Chat Completions providers like :ollama and :deepseek
chat = RubyLLM.chat(model: 'qwen3', provider: :ollama)
              .with_params(response_format: { type: 'json_object' })
```

**With great power comes great responsibility:** The `with_params` method can override any part of the request payload, including critical parameters like model, max_tokens, or tools. Use it carefully to avoid unintended behavior. Always verify that your overrides are compatible with the provider's API. To debug and see the exact request being sent, set the environment variable `RUBYLLM_DEBUG=true`.
{: .warning }

Available parameters vary by provider and model. Always consult the provider's documentation for supported features. RubyLLM passes these parameters through without validation, so incorrect parameters may cause API errors. Parameters from `with_params` take precedence over RubyLLM's defaults, allowing you to override any aspect of the request payload.
{: .warning }

## Choosing the Wire Protocol
{: .d-inline-block }

v2.0+
{: .label .label-green }

Some providers speak more than one wire protocol. OpenAI defaults to the Responses API and routes audio models to Chat Completions; Vertex AI speaks Gemini for Google models, Anthropic for Claude, Mistral for Mistral, and Chat Completions for the publisher-prefixed MaaS models. RubyLLM picks the right protocol per request:

```ruby
chat = RubyLLM.chat(model: 'claude-opus-4-6', provider: :vertexai)               # speaks Anthropic
chat = RubyLLM.chat(model: 'meta/llama-3.3-70b-instruct-maas', provider: :vertexai) # speaks Chat Completions
```

Override it per chat or app-wide:

```ruby
chat = RubyLLM.chat(model: 'gpt-5.4').with_protocol(:chat_completions)

RubyLLM.configure do |config|
  config.openai_protocol = :chat_completions
end
```

Unknown protocol names raise immediately, listing what the provider speaks.

## Raw Content Blocks

Most of the time you can rely on RubyLLM to format messages for each provider. When you need to send a custom payload as content, wrap it in `RubyLLM::Content::Raw`. The block is forwarded verbatim, with no additional processing.

```ruby
raw_block = RubyLLM::Content::Raw.new([
  { type: 'text', text: 'Reusable analysis prompt' },
  { type: 'text', text: "Today's request: #{summary}" }
])

chat = RubyLLM.chat
chat.add_message(role: :system, content: raw_block)
chat.ask(raw_block)
```

Use raw blocks sparingly: they bypass cross-provider safeguards, so it is your responsibility to ensure the payload matches the provider's expectations. `Chat#ask`, `Chat#add_message`, tool results, and streaming accumulators all understand `Content::Raw` values.

### Anthropic Prompt Caching

One use case for Raw Content Blocks is Anthropic Prompt Caching.

Anthropic lets you mark individual prompt blocks for caching, which can dramatically reduce costs on long conversations. RubyLLM provides a convenience builder that returns a `Content::Raw` instance with the proper structure:

```ruby
system_block = RubyLLM::Providers::Anthropic::Content.new(
  "You are a release-notes assistant. Always group changes by subsystem.",
  cache: true # shorthand for cache_control: { type: 'ephemeral' }
)

chat = RubyLLM.chat(model: '{{ site.models.anthropic_latest }}')
chat.add_message(role: :system, content: system_block)

response = chat.ask(
  RubyLLM::Providers::Anthropic::Content.new(
    "Summarize the API changes in this diff.",
    cache_control: { type: 'ephemeral', ttl: '1h' }
  )
)
```

Need something even more custom? Build the payload manually and wrap it in `Content::Raw`:

```ruby
raw_prompt = RubyLLM::Content::Raw.new([
  { type: 'text', text: File.read('/a/large/file'), cache_control: { type: 'ephemeral' } },
  { type: 'text', text: "Today's request: #{summary}" }
])

chat.ask(raw_prompt)
```

The same idea applies to tool definitions:

```ruby
class ChangelogTool < RubyLLM::Tool
  description "Formats commits into human-readable changelog entries."
  param :commits, type: :array, desc: "List of commits to summarize"

  with_params cache_control: { type: 'ephemeral' }

  def execute(commits:)
    # ...
  end
end
```

Providers that do not understand these extra fields silently ignore them, so you can reuse the same tools across models.
See the [Tool Provider Parameters]({% link _core_features/tool-parameters.md %}#provider-specific-parameters) section for more detail.

## Custom HTTP Headers

Some providers offer beta features or special capabilities through custom HTTP headers. The `with_headers` method lets you add these headers to your API requests while maintaining RubyLLM's security model.

```ruby
chat = RubyLLM.chat(model: '{{ site.models.anthropic_current }}')
      .with_headers('anthropic-beta' => 'fine-grained-tool-streaming-2025-05-14')

response = chat.ask "Tell me about the weather"
```

Headers are merged with provider defaults, with provider headers taking precedence for security. This means you can't override authentication or critical headers, but you can add supplementary headers for optional features.

```ruby
chat = RubyLLM.chat
      .with_temperature(0.5)
      .with_headers('X-Custom-Feature' => 'enabled')
      .with_params(max_tokens: 1000)
```

Use custom headers with caution. They may enable experimental features that could change or be removed without notice. Always refer to your provider's documentation for supported headers and their behavior.
{: .warning }

## Next Steps

* [Chat]({% link _core_features/chat.md %}) - the core conversation interface.
* [Tool Parameters]({% link _core_features/tool-parameters.md %}) - pass provider-specific options to tool definitions.
* [Structured Output]({% link _core_features/structured-output.md %}) - get schema-validated responses instead of raw JSON mode.
* [Configuration]({% link _getting_started/configuration.md %}) - set provider protocols and defaults app-wide.

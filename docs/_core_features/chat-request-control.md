---
layout: default
title: Advanced Request Control
parent: "Chat"
nav_order: 8
description: Reach provider-specific features with custom parameters, wire protocols, request hooks, and HTTP headers
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

* How to pass options in the provider's request vocabulary with `with_provider_options`.
* How to choose the wire protocol a provider speaks.
* How to modify the final request payload with `before_request`.
* How to add custom HTTP headers to a request.

## Fluent Configuration

Chat configuration methods use a chainable `with_*` style:

```ruby
chat = RubyLLM.chat
              .with_temperature(0.2)
              .with_max_output_tokens(200)
```

Calling a `with_*` method again replaces the setting. Every clearable setting has a matching `without_*` method that returns it to its default:

```ruby
chat.with_temperature(0.2)
chat.without_temperature

chat.with_caching(ttl: "1h")
chat.without_caching

chat.with_max_output_tokens(200)
chat.without_max_output_tokens

chat.with_headers("X-Custom-Feature" => "enabled")
chat.without_headers

chat.with_thinking(effort: :high)
chat.without_thinking

chat.with_tools(SearchDocs)
chat.without_tools

chat.with_citations
chat.without_citations

chat.with_instructions "Be terse."
chat.without_instructions
```

The same pattern covers `with_schema`/`without_schema`, `with_fallbacks`/`without_fallbacks`, and `with_context`/`without_context`. Passing `nil` to a `with_*` method raises `ArgumentError` pointing at its `without_*` sibling.

Methods with no arguments enable a feature with its default behavior, like provider-default prompt caching with `with_caching` or document citations with `with_citations`.

## Provider Options

Different providers offer unique features and request fields. The `with_provider_options` method takes options written in the provider's own request vocabulary and merges them into the request as-is, overriding any defaults set by RubyLLM. It is the escape hatch for anything RubyLLM does not model as a first-class option.

```ruby
# JSON object mode on the Responses API (OpenAI's default protocol)
chat = RubyLLM.chat.with_provider_options(text: { format: { type: 'json_object' } })
response = chat.ask "What is the square root of 64? Answer with a JSON object with the key `result`."
puts JSON.parse(response.content)

# The same option on Chat Completions providers like :ollama and :deepseek
chat = RubyLLM.chat(model: 'qwen3', provider: :ollama)
              .with_provider_options(response_format: { type: 'json_object' })
```

**With great power comes great responsibility:** The `with_provider_options` method can override any part of the request payload, including critical parameters like model, max_tokens, or tools. Use it carefully to avoid unintended behavior. Always verify that your overrides are compatible with the provider's API. To debug and see the exact request being sent, set the environment variable `RUBYLLM_DEBUG=true`.
{: .warning }

Available options vary by provider and model. Always consult the provider's documentation for supported fields. RubyLLM passes these options through without validation, so incorrect options may cause API errors. Options from `with_provider_options` take precedence over RubyLLM's defaults, allowing you to override any aspect of the request payload.
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

Override it per chat with the `protocol:` model option, or app-wide with configuration:

```ruby
chat = RubyLLM.chat(model: 'gpt-5.4', protocol: :chat_completions)
chat = RubyLLM.chat(model: 'gpt-5.4').with_model('gpt-5.4', protocol: :chat_completions)

RubyLLM.configure do |config|
  config.openai_protocol = :chat_completions
end
```

The `protocol:` option sits alongside `provider:` in model selection: a model is identified by its name, its provider, and its protocol. Unknown protocol names raise immediately, listing what the provider speaks. A bare `with_model` returns the chat to the provider's default protocol, just as it re-resolves the provider.

## Request Hooks

Most of the time you can rely on RubyLLM to format messages for each provider. When a provider ships a block type RubyLLM has not wrapped yet, use `before_request` to see the fully rendered payload and adjust it before it is sent. The hook runs on every request, after all RubyLLM formatting and `with_provider_options` merging.

```ruby
chat = RubyLLM.chat
chat.before_request do |payload|
  payload[:messages].last[:content] << { type: 'custom_context', data: provider_specific_payload }
end
chat.ask('Analyze this request using the provider-native block above.')
```

Hooks mutate the payload in place; return values are ignored (use `payload.replace(new_payload)` to swap it wholesale). Use hooks sparingly: they operate on the provider's wire format, so it is your responsibility to match what the provider expects, and switching providers means revisiting the hook. Nothing a hook adds is persisted; it is applied fresh on each request. For prompt reuse, prefer [Prompt Caching]({% link _core_features/prompt-caching.md %}).

`Chat#render` returns the request the chat would send, with hooks applied, which makes hook output easy to inspect and test.

The same idea applies to tool definitions:

```ruby
class ChangelogTool < RubyLLM::Tool
  description "Formats commits into human-readable changelog entries."
  parameter :commits, type: :array, description: "List of commits to summarize"

  provider_options cache_control: { type: 'ephemeral' }

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
      .with_provider_options(max_tokens: 1000)
```

Use custom headers with caution. They may enable experimental features that could change or be removed without notice. Always refer to your provider's documentation for supported headers and their behavior.
{: .warning }

## Next Steps

* [Chat]({% link _core_features/chat.md %}) - the core conversation interface.
* [Tool Parameters]({% link _core_features/tool-parameters.md %}) - pass provider-specific options to tool definitions.
* [Structured Output]({% link _core_features/structured-output.md %}) - get schema-validated responses instead of raw JSON mode.
* [Configuration]({% link _getting_started/configuration.md %}) - set provider protocols and defaults app-wide.

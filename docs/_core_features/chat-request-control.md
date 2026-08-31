---
layout: default
title: Advanced Request Control
parent: "Chat"
nav_order: 8
description: Reach provider-specific features with custom parameters, wire protocols, request hooks, and HTTP headers
---

# {{ page.title }}

{{ page.description }}
{: .fs-6 .fw-300 }

After reading this guide, you will know:

* How to identify end users to a provider's abuse tooling with `with_end_user`.
* How to keep long conversations inside the context window with `with_compaction`.
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

Calling a `with_*` method again replaces the setting. Value setters use `nil` to clear a value; feature switches use `false` to disable the feature:

```ruby
chat.with_temperature(0.2)
chat.with_temperature(nil)

chat.with_caching(ttl: "1h")
chat.with_caching(false)

chat.with_max_output_tokens(200)
chat.with_max_output_tokens(nil)

chat.with_headers("X-Custom-Feature" => "enabled")
chat.with_headers(nil)

chat.with_thinking(effort: :high)
chat.with_thinking(false)

chat.with_tools(SearchDocs)
chat.with_tools(nil)

chat.with_citations
chat.with_citations(false)

chat.with_instructions "Be terse."
chat.with_instructions(nil)
```

The same pattern covers `with_schema`, `with_fallbacks`, `with_provider_options`, and `with_context`.

Methods with no arguments enable a feature with its default behavior. Pass `false` to disable it:

```ruby
chat.with_caching
chat.with_caching(false)

chat.with_thinking
chat.with_thinking(false)

chat.with_compaction
chat.with_compaction(false)

chat.with_citations
chat.with_citations(false)
```

## Identifying End Users

Providers offer a per-user identifier so they can attribute abuse to one of your users instead of your whole account. `with_end_user` sets it once and RubyLLM maps it to whatever the provider calls it:

```ruby
chat = RubyLLM.chat.with_end_user("user-#{current_user.id}")
chat.ask "Hello"
```

| Provider | Request field |
|:---------|:--------------|
| OpenAI, Azure | `safety_identifier` |
| Anthropic | `metadata.user_id` |
| DeepSeek | `user_id` |
| OpenRouter | `user` |
| Everything else | omitted |

The value goes to the provider as given, so send an opaque id such as a hash or a UUID, never an email address or any other personal data.
{: .warning }

Providers without an equivalent field drop it and log the decision at debug level, so the same code works across every model.

Agents declare it with the matching `end_user` macro, which also takes a block:

```ruby
class SupportAgent < RubyLLM::Agent
  inputs :account
  end_user { account.public_id }
end
```

## Compacting Long Conversations

A conversation that runs long enough overflows the model's context window and the provider starts rejecting requests. Several providers can handle that themselves: once the conversation crosses a token threshold, the provider condenses the earlier turns and carries on. `with_compaction` turns it on:

```ruby
chat = RubyLLM.chat(model: "claude-sonnet-5").with_compaction
chat.ask "Let's go through the whole migration plan."
```

With no arguments the provider's own defaults apply. Three provider-neutral options tune it:

```ruby
chat.with_compaction(at: 50_000)
chat.with_compaction(at: 100_000, instructions: "Keep every decision and open question.")
chat.with_compaction(at: 50_000, pause_after: true)
chat.with_compaction(false)
```

`at:` is the input-token count that triggers compaction, `instructions:` steers the summary the provider writes, and `pause_after:` ends the turn once compaction runs instead of continuing straight into the answer. `false` turns compaction back off. Each provider maps what it supports:

| Provider | Request field | `at:` | `instructions:` and `pause_after:` |
|:---------|:--------------|:------|:-----------------------------------|
| Anthropic, Bedrock (Mantle) | `context_management.edits[].trigger.value` | yes, minimum 50,000 | yes |
| OpenAI, Azure (Responses) | `context_management[].compact_threshold` | yes | dropped |
| OpenRouter | `plugins[]` entry `context-compression` | dropped | dropped |
| Everything else | omitted | | |

Providers with nothing equivalent drop the request and log the decision at debug level, so the same code runs against every model. Compaction is also newer than most models: Anthropic serves it on Claude Sonnet 4.6, Opus 4.6 and later, and the 5 series, and OpenAI on GPT-5.2 and later.

What happens at the threshold is not the same everywhere. Anthropic and OpenAI summarize the compacted span and return an opaque block in its place, which RubyLLM keeps on the message and replays on every later request, so the model still knows what was decided. OpenRouter's `context-compression` plugin drops messages from the middle of the conversation rather than summarizing them, and it triggers at the model's own context limit rather than at a threshold you pick.
{: .warning }

Compacting is not free: the provider runs the model an extra time to write the summary, and that generation is billed. RubyLLM reports the whole bill, so `response.tokens.input` on a turn that compacted counts the summarization pass as well as the answer.

Agents declare it with `compaction`:

```ruby
class ResearchAgent < RubyLLM::Agent
  model "claude-sonnet-5"
  compaction at: 50_000
end
```

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

`with_provider_options` can override any part of the request payload, including the model, token limits, and tools, and RubyLLM passes it through without validation. Available options vary by provider and model, so consult the provider's documentation before overriding anything. To see the exact request being sent, set `RUBYLLM_DEBUG=true`.
{: .warning }

## Choosing the Wire Protocol

Some providers speak more than one wire protocol. OpenAI defaults to the Responses API and routes audio models to Chat Completions; Azure defaults to Chat Completions and routes deployments named after gpt-5.4+ models to the Responses API; Vertex AI speaks Gemini for Google models, Anthropic for Claude, Mistral for Mistral, and Chat Completions for the publisher-prefixed MaaS models. RubyLLM picks the right protocol per request:

```ruby
chat = RubyLLM.chat(model: 'claude-opus-5', provider: :vertexai)                 # speaks Anthropic
chat = RubyLLM.chat(model: 'meta/llama-3.3-70b-instruct-maas', provider: :vertexai) # speaks Chat Completions
```

Override it per chat with the `protocol:` model option, or app-wide with configuration:

```ruby
chat = RubyLLM.chat(model: 'gpt-5.6', protocol: :chat_completions)
chat = RubyLLM.chat(model: 'gpt-5.6').with_model('gpt-5.6', protocol: :chat_completions)

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

### Inspecting the Payload

To see the exact request a chat would send, without sending it, call `render`. It returns the payload with all formatting, `with_provider_options` merging, and `before_request` hooks applied, which makes it handy in tests:

```ruby
payload = chat.with_provider_options(service_tier: "flex").render
payload[:service_tier] # => "flex"
```

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

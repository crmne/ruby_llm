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
* How to compact long conversations automatically or when you choose.
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

Value setters accept `nil` to clear a setting. Feature switches accept no arguments to enable their default behavior, options to configure it, and `false` to disable it:

```ruby
chat.with_temperature(0.2)
chat.with_temperature(nil)

chat.with_thinking(effort: :high)
chat.with_thinking(false)

chat.with_caching
chat.with_caching(false)
```

The same feature-switch pattern applies to `with_citations` and `with_compaction`. These switches reject `nil`. `with_tools(nil)` clears the tool list; other tool settings are covered in [Controlling Tool Execution]({% link _core_features/tool-execution.md %}).

## Identifying End Users

Providers offer a per-user identifier so they can attribute abuse to one of your users instead of your whole account. `with_end_user` sets it once and RubyLLM maps it to whatever the provider calls it:

```ruby
chat = RubyLLM.chat.with_end_user("user-#{current_user.id}")
chat.ask "Hello"
```

Use an opaque ID such as an account's public ID or a UUID. The value is sent as given. Providers without support for end-user attribution ignore this setting.

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
chat = RubyLLM.chat(model: "{{ site.models.anthropic_current }}").with_compaction
chat.ask "Let's go through the whole migration plan."
```

With no arguments the provider's own defaults apply. Three provider-neutral options tune it:

```ruby
chat.with_compaction(at: 50_000)
chat.with_compaction(at: 100_000, instructions: "Keep every decision and open question.")
chat.with_compaction(at: 50_000, pause_after: true)
chat.with_compaction(false)
```

`at:` sets the input-token threshold. `instructions:` guides the summary, and `pause_after:` stops the turn after compaction. Support differs:

| Provider | Automatic compaction behavior |
| --- | --- |
| Anthropic and Bedrock Mantle | Summarizes earlier turns; supports all three options, with a minimum threshold of 50,000 tokens |
| OpenAI and Azure Responses | Summarizes earlier turns; supports `at:` |
| OpenRouter | Drops messages from the middle at the model's context limit; ignores these options |

Use a model that supports compaction. Unsupported providers ignore the setting. Summarization can incur additional usage and charges, which are included in the response's tokens and cost.

Agents declare it with `compaction`:

```ruby
class ResearchAgent < RubyLLM::Agent
  model "{{ site.models.anthropic_current }}"
  compaction at: 50_000
end
```

### Compacting Now

Call `compact` to reduce the context sent on subsequent requests while keeping every message in your transcript:

```ruby
chat = RubyLLM.chat(model: "{{ site.models.xai_tokenization }}", provider: :xai)
chat.ask "The project codename is Thimble. We write it in Ruby."

summary = chat.compact
chat.ask "What is the project codename?"

summary.tokens.input
summary.cost.total
chat.messages # includes the original conversation and the compaction message
```

Manual compaction works with xAI, OpenAI, and Azure through their Responses APIs. For Azure deployments using Chat Completions by default, pass `protocol: :responses` when creating the chat. It is separate from `with_compaction`, which asks the provider to compact automatically during generation.

`compact` returns a `Message` whose text can be empty. Later requests use its compacted context while your transcript keeps the original messages. You can still change instructions with `with_instructions`. The returned message and `chat.tokens` include compaction usage.

The same call works on an agent or a Rails chat. Rails persists the compacted context and usage, and `Agent.find` or a reloaded chat can continue from it without deleting earlier messages. Finish any pending tool calls, including approval decisions, before compacting.

Compaction uses the current HTTP headers and `before_request` hooks. Generation options such as tools, temperature, and `provider_options` are not forwarded to the compaction endpoint. Keep the conversation on a provider and model that can read its compacted context.

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

RubyLLM normally selects the protocol for your model and operation. Choose one explicitly when a guide requires a different endpoint, such as Responses for a provider's hosted tools.

Override it per chat with the `protocol:` model option, or app-wide with configuration:

```ruby
chat = RubyLLM.chat(model: 'gpt-5.6', protocol: :chat_completions)
chat = RubyLLM.chat(model: 'gpt-5.6').with_model('gpt-5.6', protocol: :chat_completions)

RubyLLM.configure do |config|
  config.openai_protocol = :chat_completions
end
```

The `protocol:` option sits alongside `provider:` in model selection: a model is identified by its name, its provider, and its protocol. Unknown protocol names raise when the request is rendered or sent, listing the protocols the provider supports. A bare `with_model` returns the chat to the provider's default protocol, just as it re-resolves the provider.

### Perplexity Router

Perplexity's Router requires separate account access and an explicit protocol. Use it for function tools, tool-choice controls, and cache boundaries:

```ruby
chat = RubyLLM.chat(model: "{{ site.models.perplexity_router }}", provider: :perplexity,
                   protocol: :router_chat_completions)
              .with_tools(SearchDocs)
              .with_tool_options(choice: :required, calls: :one)

chat.ask "Find the installation guide."
```

Router requires tool descriptions and strict JSON schemas. For hosted search and MCP, use the Agent protocol described in [Server Tools]({% link _core_features/server-tools.md %}#protocol-selection).

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

Some providers offer beta features or special capabilities through custom HTTP headers. Use `with_headers` to add them to your requests.

```ruby
chat = RubyLLM.chat(model: '{{ site.models.anthropic_current }}')
      .with_headers('anthropic-beta' => 'fine-grained-tool-streaming-2025-05-14')

response = chat.ask "Tell me about the weather"
```

Headers are merged with provider defaults, with provider headers taking precedence for security. This means you can't override authentication or critical headers, but you can add supplementary headers for optional features.


## Next Steps

* [Chat]({% link _core_features/chat.md %}) - the core conversation interface.
* [Tool Parameters]({% link _core_features/tool-parameters.md %}) - pass provider-specific options to tool definitions.
* [Structured Output]({% link _core_features/structured-output.md %}) - get schema-validated responses instead of raw JSON mode.
* [Configuration]({% link _getting_started/configuration.md %}) - set provider protocols and defaults app-wide.

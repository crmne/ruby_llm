---
layout: default
title: Extended Thinking
parent: "Chat"
nav_order: 4
description: Give reasoning models more time and budget to deliberate, with optional access to thinking output
redirect_from:
  - /guides/thinking
  - /guides/reasoning
---

# {{ page.title }}

{{ page.description }}
{: .fs-6 .fw-300 }

After reading this guide, you will know:

* How to control extended thinking with `with_thinking`
* How effort and budget are sent to providers
* How to access thinking output in responses and streams
* How to persist thinking data with ActiveRecord

## What is Extended Thinking?

Extended Thinking gives supported models more time and a larger computation budget to deliberate before answering. It can improve results on multi-step tasks like coding, math, and logic, at the expense of latency and cost. Some providers can also return a thinking trace or signature alongside the final answer.

## Controlling Extended Thinking

Call `with_thinking` without options to enable thinking with the current model's registered controls:

```ruby
chat = RubyLLM.chat(model: 'claude-opus-4-5').with_thinking
```

RubyLLM resolves those controls when it builds the request, so it follows later model changes and fallbacks. The registry may select an effort, a token budget, a provider toggle, or no request option for a model that always thinks. If the registry does not know how to enable thinking for the selected model, RubyLLM raises an `ArgumentError` instead of guessing.

When the registry lists several controls, RubyLLM prefers an explicit default, then a provider toggle, then `medium` effort when available, then the smallest positive token budget the model accepts. Each protocol then sends what its provider needs to think at that level; on Claude, for example, an effort alone never turns thinking on, so RubyLLM adds the thinking block the generation takes (see [Provider Notes](#provider-notes)).

Pass options when you want to tune the model explicitly:

```ruby
chat = RubyLLM.chat(model: 'claude-opus-4-5')
  .with_thinking(effort: :high, budget: 8000)

response = chat.ask("What is 15 * 23?")

response.thinking&.text
response.thinking&.signature
response.content
```

Pass `effort`, `budget`, or both:

```ruby
chat.with_thinking(effort: :low)
chat.with_thinking(budget: 10_000)
chat.with_thinking(effort: :none)
```

Pass `false` to disable thinking:

```ruby
chat.with_thinking(false)
```

Disabling is model-specific too. RubyLLM sends the registered off control and raises an `ArgumentError` when the model does not expose one. Passing `nil` is invalid.

### Effort and Budget

Use `effort` to pick a qualitative depth (`:low`, `:medium`, `:high`) and `budget` for models that accept a token cap.

RubyLLM sends `effort` and `budget` exactly as provided, and never rewrites a value to one the registry believes a model takes. Check your provider's docs for supported values. When a model does not accept the value you picked, the request fails with the provider's own error, which names the parameter and usually lists the values it takes.

### Display

Some providers let you choose how much of the thinking comes back with the response. Pass `display:` and RubyLLM forwards the value in the provider's request shape:

```ruby
chat.with_thinking(effort: :high, display: :summarized)  # a summary of the thinking
chat.with_thinking(effort: :high, display: :omitted)     # think, but return no thinking text
```

## Streaming with Thinking

Thinking content is delivered alongside normal content in streaming chunks:

```ruby
chat = RubyLLM.chat(model: 'claude-opus-5')
  .with_thinking(effort: :medium, display: :summarized)

chat.ask("Solve this step by step: What is 127 * 43?") do |chunk|
  print chunk.thinking&.text
  print chunk.content
end
```

Some providers only expose thinking in the final response. In those cases, `response.thinking` is populated after the stream completes, and `chunk.thinking` stays empty.

## ActiveRecord Integration

When using `acts_as_chat` and `acts_as_message`, thinking content is persisted with the message while thinking-token accounting is stored in RubyLLM's internal usage ledger:

```ruby
# Migration (generated automatically with new installs)
# t.text :thinking_text
# t.text :thinking_signature

response = chat_record.ask("Explain quantum entanglement")
response.thinking&.text
response.tokens.thinking
```

`tokens.thinking` reports reasoning work separately. `tokens.output` is already the billable output bucket, so do not add `tokens.thinking` to it when calculating costs. When a model has distinct reasoning-token pricing, the cost is exposed separately as `response.cost.thinking`.

Apps upgrading from 1.16 get the thinking columns from `bin/rails generate ruby_llm:upgrade`. See [Upgrading]({% link _reference/upgrading.md %}).

## Provider Notes

- Anthropic sends each option to its own Claude parameter: `budget` becomes a thinking budget, `effort` becomes Claude's effort setting, and `display` chooses how much thinking text comes back. Effort alone never turns thinking on for Claude, so RubyLLM always sends a thinking block beside it. Generations that take a budget (Opus 4.5, Opus and Sonnet 4.6, Sonnet and Haiku 4.5) get `budget:` when you set one, otherwise a budget sized from the effort with the levels Bedrock publishes (low 1024, medium 40000, high 63999), capped under `max_tokens`. Generations without a budget option (Opus 4.7 and later, Sonnet 5, Fable 5) get adaptive thinking, where the model decides how much to think. `with_thinking(false)` sends a disabled block on every generation. Newer Claude models keep their thinking text hidden, so pass `display: :summarized` when you want to read it.
- Bedrock thinking params are model-dependent. Claude models on Bedrock only take a token budget, so RubyLLM converts `effort` into the budget level the model advertises. Pass `budget` to set the exact number of tokens.
- Gemini 2.5 uses a token budget; Gemini 3 uses effort levels.
- OpenAI reasoning models accept `effort`, return an encrypted signature, and only return thinking text when you pass `display: :summarized`, which asks the Responses API for a reasoning summary.
- Perplexity sonar reasoning models fold their reasoning into the answer text and return no separate thinking.
- Mistral sends `effort` as `reasoning_effort` for every model. Its reasoning models take `high` and `none`, and models without reasoning reject the parameter. Mistral has no thinking budget, so `budget` has no effect.
- DeepSeek accepts a wider range of effort levels than most providers and has no thinking budget. Its error lists the levels a model takes.
- Cohere reasoning models think by default. `with_thinking(budget:)` caps the thinking tokens, and `with_thinking(effort: :none)` turns the default off. Models without reasoning reject the request. Cohere returns thinking text but no signature, and reports no separate thinking token count.
- Ollama and GPUStack local-model thinking controls vary by backend and model. RubyLLM does not translate them; pass backend params explicitly with `with_provider_options`.
- Ollama does not report thinking token counts.

## Next Steps

* [Streaming Responses]({% link _core_features/streaming.md %})
* [Rails Integration]({% link _advanced/rails.md %})
* [Error Handling]({% link _advanced/error-handling.md %})

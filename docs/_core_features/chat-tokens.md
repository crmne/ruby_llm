---
layout: default
title: Token Usage and Cost
parent: "Chat"
nav_order: 7
description: Read per-turn and per-conversation token counts and costs, with normalized cache and thinking buckets across providers
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

* How to read input, output, cache, and thinking token counts from a response.
* How to compute token totals for a full conversation.
* How to read per-turn and per-conversation costs.
* How RubyLLM normalizes token buckets across providers.
* How thinking and cache pricing are handled.

## Tracking Token Usage

Understanding token usage is important for managing costs and staying within context limits. Each `RubyLLM::Message` returned by `ask` includes token counts.

```ruby
response = chat.ask "Explain the Ruby Global Interpreter Lock (GIL)."

input_tokens = response.tokens.input   # Standard input tokens
output_tokens = response.tokens.output # Billable output tokens
cache_read_tokens = response.tokens.cache_read # Tokens served from the provider's prompt cache - v1.15+
cache_write_tokens = response.tokens.cache_write # Tokens written to cache - v1.15+
thinking_tokens = response.tokens.thinking # Thinking tokens when providers report them - v1.10.0+
request_side_input_tokens = input_tokens.to_i + cache_read_tokens.to_i + cache_write_tokens.to_i

puts "Input Tokens: #{input_tokens}"
puts "Output Tokens: #{output_tokens}"
puts "Cache Read Tokens: #{cache_read_tokens}" # v1.15+
puts "Cache Write Tokens: #{cache_write_tokens}" # v1.15+
puts "Thinking Tokens: #{thinking_tokens}" # v1.10.0+
puts "Request-side Input Tokens: #{request_side_input_tokens}" # v1.15+
puts "Standard Tokens for this turn: #{input_tokens.to_i + output_tokens.to_i}"

puts "Input Cost: $#{format('%.6f', response.cost.input)}" if response.cost.input
puts "Output Cost: $#{format('%.6f', response.cost.output)}" if response.cost.output
puts "Cache Read Cost: $#{format('%.6f', response.cost.cache_read)}" if response.cost.cache_read
puts "Cache Write Cost: $#{format('%.6f', response.cost.cache_write)}" if response.cost.cache_write
puts "Thinking Cost: $#{format('%.6f', response.cost.thinking)}" if response.cost.thinking
puts "Total Cost: $#{format('%.6f', response.cost.total)}" if response.cost.total

total_conversation_tokens = chat.messages.sum do |msg|
  msg.tokens&.input.to_i + msg.tokens&.output.to_i + msg.tokens&.cache_read.to_i + msg.tokens&.cache_write.to_i
end
puts "Total Conversation Tokens: #{total_conversation_tokens}"

puts "Total Conversation Cost: $#{format('%.6f', chat.cost.total)}" if chat.cost.total
```

RubyLLM handles provider token differences for you. From v1.15 onward, `tokens.input` means the standard input bucket used for pricing. Cache activity is exposed separately as `tokens.cache_read` and `tokens.cache_write`, even when the provider includes those tokens in a raw prompt total.

| Provider | Raw provider usage | RubyLLM exposes |
| --- | --- | --- |
| OpenAI, Azure OpenAI, xAI, OpenAI-compatible | `prompt_tokens` can include `prompt_tokens_details.cached_tokens`; cache writes may appear as `cache_write_tokens`. | `tokens.input` excludes cache reads and writes. `tokens.cache_read` and `tokens.cache_write` receive the cache buckets. |
| DeepSeek | `prompt_tokens` is split into `prompt_cache_hit_tokens` and `prompt_cache_miss_tokens`. | `tokens.input` is cache misses. `tokens.cache_read` is cache hits. |
| OpenRouter | `prompt_tokens` can include cached tokens and cache-write tokens in `prompt_tokens_details`. | `tokens.input` excludes both cache buckets. `tokens.cache_read` and `tokens.cache_write` receive the cache buckets. |
| Anthropic | `input_tokens` is already separate from `cache_read_input_tokens` and `cache_creation_input_tokens` or the `cache_creation` breakdown. | `tokens.input` passes through. Cache buckets map to `tokens.cache_read` and `tokens.cache_write`. |
| Bedrock | `inputTokens` includes `cacheReadInputTokens` and `cacheWriteInputTokens`. | `tokens.input` excludes both cache buckets. Cache buckets are exposed separately. |
| Gemini and Vertex AI | `promptTokenCount` includes `cachedContentTokenCount`. | `tokens.input` excludes cached content. `tokens.cache_read` receives cached content tokens. |
| Providers without cache fields | Only standard input and output usage is reported. | Cache buckets stay `nil`; `tokens.input` stays as the provider input count. |

This means the same RubyLLM code works across providers: `tokens.input` for standard input, `tokens.output` for output, `tokens.cache_read` for prompt cache reads, and `tokens.cache_write` for prompt cache writes. To display the full request-side input activity, add `tokens.input + tokens.cache_read + tokens.cache_write`.

The top-level token helpers remain available for compatibility with v1.9.0+ code, but new code should prefer `response.tokens.*`.

Thinking token usage is available via `response.tokens.thinking` when providers report it. For most providers, thinking/reasoning tokens are a breakdown of output work, not an extra bucket to add yourself. RubyLLM keeps `tokens.output` as the billable output bucket: OpenAI-style providers that include reasoning in completion tokens stay as-is, while OpenAI-compatible providers that report reasoning outside completion tokens are normalized so `tokens.output` includes the billable generated total.

When a model has distinct reasoning-token pricing, `response.cost.thinking` prices that bucket separately. Otherwise, thinking tokens are treated as part of `response.cost.output` and `response.cost.thinking` stays `nil`.

Cost helpers are available from v1.15+. RubyLLM uses token usage from the provider and pricing from the model registry. If the registry is missing pricing for tokens that were used, the affected cost and `cost.total` return `nil` instead of pretending the cost was zero. These helpers cover token-priced conversation usage; provider-specific add-ons such as search-query charges are left to the provider's raw usage payload.

Refer to [Working with Models]({% link _reference/models.md %}) for details on accessing model-specific pricing.

## Next Steps

* [Chat]({% link _core_features/chat.md %}) - the core conversation interface these counts come from.
* [Working with Models]({% link _reference/models.md %}) - inspect model-specific pricing in the registry.
* [Extended Thinking]({% link _core_features/thinking.md %}) - work with reasoning-capable models.
* [Instrumentation and Observability]({% link _advanced/instrumentation.md %}) - emit token and cost metrics in production.

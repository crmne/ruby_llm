---
layout: default
title: Tokens and Costs
parent: "Chat"
nav_order: 9
description: Read normalized token counts and costs for every response, chat, and provider attempt, including retries and cancellations.
redirect_from:
  - /chat-tokens/
  - /model-costs/
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
* How to read per-turn and per-conversation costs.
* How RubyLLM normalizes token buckets across providers.
* How the internal usage ledger accounts for retries, fallbacks, and cancellations.
* How to price token usage yourself with `cost_for` and `Cost.aggregate`.
* How costs are recorded in Rails and how to keep registry pricing fresh.

## Reading Tokens and Costs

Token counts always live on a `RubyLLM::Tokens` value, and costs always live on a `RubyLLM::Cost` value. Both objects are present even when a provider does not report every field; unknown fields are `nil`:

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
puts "Request-side Input Tokens: #{request_side_input_tokens}"

puts "Input Cost: $#{format('%.6f', response.cost.input)}" if response.cost.input
puts "Output Cost: $#{format('%.6f', response.cost.output)}" if response.cost.output
puts "Total Cost: $#{format('%.6f', response.cost.total)}" if response.cost.total

puts "Total Conversation Cost: $#{format('%.6f', chat.cost.total)}" if chat.cost.total
```

`response.tokens` aggregates every transport attempt associated with the response. `chat.tokens` and `chat.cost` aggregate the chat's whole internal ledger, including failed retries and cancelled attempts (see [The Usage Ledger](#the-usage-ledger) below).

The same pair of value objects is used by one-shot results. Their fields remain `nil` when the provider does not report enough information:

```ruby
embedding = RubyLLM.embed("Ruby")
embedding.tokens.input
embedding.cost.total

transcription = RubyLLM.transcribe("meeting.wav")
transcription.tokens.input
transcription.tokens.output
transcription.cost.total
```

Cost helpers are available from v1.15+. RubyLLM uses token usage from the provider and pricing from the model registry. If the registry is missing pricing for tokens that were used, the affected cost and `cost.total` return `nil` instead of pretending the cost was zero. These helpers cover token-priced conversation usage; provider-specific add-ons such as search-query charges are left to the provider's raw usage payload.

## How Providers Are Normalized

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

Thinking token usage is available via `response.tokens.thinking` when providers report it. For most providers, thinking/reasoning tokens are a breakdown of output work, not an extra bucket to add yourself. RubyLLM keeps `tokens.output` as the billable output bucket: OpenAI-style providers that include reasoning in completion tokens stay as-is, while OpenAI-compatible providers that report reasoning outside completion tokens are normalized so `tokens.output` includes the billable generated total.

When a model has distinct reasoning-token pricing, `response.cost.thinking` prices that bucket separately. Otherwise, thinking tokens are treated as part of `response.cost.output` and `response.cost.thinking` stays `nil`.

## The Usage Ledger

An LLM transcript is not an accounting ledger. A request can be retried before one response arrives, and a cancelled stream can consume tokens without producing a completed assistant message. Counting messages therefore undercounts real provider work.

RubyLLM records each physical provider attempt internally. This changes the implementation of token and cost helpers without adding a tracking object to the public API.

One response can require several physical attempts. If a transport request fails twice and the third attempt succeeds, the response's `tokens` and `cost` aggregate the reported usage from all three attempts.

Fallbacks work the same way. When an initial model fails and a fallback produces the message, every attempt involved in that logical generation contributes to the resulting message's aggregates.

A cancelled attempt may have no message to attach to. It still contributes to `chat.tokens` and `chat.cost` when RubyLLM has enough reported usage. If an attempt may have been billed but the provider supplied no defensible usage, the token fields for that attempt and `chat.cost.total` are `nil` rather than misleading zeroes. An attempt that provably never reached the provider, such as a refused connection or a failed TLS handshake, records zero tokens instead: it cannot have been billed, so it does not blank the total.

## Pricing Usage Yourself

Once a model is in the registry, RubyLLM can turn token usage into a `RubyLLM::Cost` object so you can attach a dollar figure to any usage payload:

```ruby
model = RubyLLM.models.find('{{ site.models.default_chat }}')
response = RubyLLM.chat(model: model.id, provider: model.provider).ask("Summarize Ruby's object model.")

cost = model.cost_for(response.tokens)
puts cost.input
puts cost.output
puts cost.cache_read
puts cost.cache_write
puts cost.thinking
puts cost.total
```

When a model publishes a long-context tier, `cost_for` uses those rates once the prompt exceeds the registry threshold. Prompt size is `input + cache_read + cache_write`. Below that threshold—or when the model has no long-context tier—standard rates apply. Batch rates remain unused by `cost_for`; see [Batches]({% link _advanced/batches.md %}).

Most applications use the shorter helpers on messages, chats, and agents: `response.cost.total`, `chat.cost.total`, `agent.cost.total`.

To combine several cost objects yourself, use `RubyLLM::Cost.aggregate`:

```ruby
cost = RubyLLM::Cost.aggregate(messages.map(&:cost))
cost.total
```

If pricing is incomplete for tokens that were used, the affected cost and `cost.total` return `nil`.

## Rails Persistence

With `acts_as_chat`, RubyLLM writes finished attempts to `ruby_llm_usage_entries` immediately. This happens before the message callback, so cancellation cannot erase usage merely because no assistant message was saved.

```ruby
chat = Chat.find(params[:id])
message = chat.messages.last

message.tokens.input
message.cost.total
chat.tokens.input
chat.cost.total
```

The ledger is internal to RubyLLM; your application still owns only its Chat and Message models. Token buckets and cost components use normalized numeric columns rather than a JSON blob. Each usage row freezes its cost in normalized decimal columns at completion, so a later `RubyLLM.models.refresh!` that changes registry pricing leaves recorded usage untouched. The upgrade migration moves token counts and frozen costs from pre-2.0 message columns into the ledger and removes those columns, so old and new rows read through the same path.

## Keeping Registry Pricing Fresh

Because recorded costs are frozen at completion, stale registry pricing only affects new attempts, never usage you have already saved. To keep new costs accurate, refresh the registry on a schedule. A daily job is a good default; providers change prices infrequently.

In a Rails app with the database-backed registry, the same refresh call writes the new pricing to RubyLLM's internal model table:

```ruby
# lib/tasks/ruby_llm.rake
namespace :ruby_llm do
  desc 'Refresh the model registry pricing and capabilities'
  task refresh_models: :environment do
    RubyLLM.models.refresh!
  end
end
```

Run `bin/rails ruby_llm:refresh_models` from cron, or schedule the call with your background job framework (GoodJob, Sidekiq, or similar). RubyLLM does not refresh the registry on its own; you choose the cadence.

## Instrumentation

Every finished physical attempt emits `usage.ruby_llm`. Use it when you need per-attempt detail for billing exports, metrics, or observability:

```ruby
ActiveSupport::Notifications.subscribe("usage.ruby_llm") do |event|
  payload = event.payload

  Metrics.increment("llm.attempt", tags: {
    provider: payload[:provider],
    model: payload[:model],
    status: payload[:status]
  })

  Metrics.distribution("llm.input_tokens", payload[:tokens].input) if payload[:tokens].input
  Metrics.distribution("llm.cost", payload[:cost].total) if payload[:cost].total
end
```

The payload contains `operation`, `provider`, `model`, `status`, `tokens`, and `cost`. It does not expose RubyLLM's internal persistence record.

`status` is `succeeded`, `failed`, or `cancelled`. `tokens` and `cost` use the same value objects returned by responses. They are always present; individual fields are `nil` when the provider did not report enough information. A failed or cancelled attempt may contain the token counts observed before it stopped.

Instrumentation is an observer, not the source of truth for a persisted Rails chat. RubyLLM maintains the internal ledger and emits the same normalized facts for applications that need them elsewhere.

## What RubyLLM Stores

The internal entry deliberately remains a small tracking fact:

| Field | Why it belongs |
|:------|:---------------|
| Chat reference | Preserves attempts that never produced a message. |
| Optional message reference | Several retries can contribute to one response; cancellation may contribute to none. |
| Operation | Supports chat and one-shot APIs with the same mechanism. |
| Provider and model | Preserve the actual route and pricing identity used by each attempt. |
| Status | Distinguishes succeeded, failed, and cancelled attempts. |
| Token buckets | Preserve provider-independent quantities used for pricing. |
| Cost components and total | Freeze historical pricing and allow ordinary database sums. |
| Rails timestamps | Order attempts and support period queries. |

Content, attachments, tool arguments, raw provider payloads, finish reasons, request timings, and exceptions do not belong in the usage ledger. They already have homes in messages or instrumentation.

## Next Steps

* [Chat]({% link _core_features/chat.md %}) - the core conversation interface these counts come from.
* [Working with Models]({% link _reference/models.md %}) - explore the registry and the `RubyLLM::Model` pricing fields behind `cost_for`.
* [Extended Thinking]({% link _core_features/thinking.md %}) - work with reasoning-capable models.
* [Instrumentation and Observability]({% link _advanced/instrumentation.md %}) - configure subscribers and custom instrumenters.
* [Persistence with acts_as]({% link _advanced/rails-persistence.md %}) - persist chats while RubyLLM manages the internal ledger.
* [Error Handling]({% link _advanced/error-handling.md %}) - recover from provider failures and configure fallbacks.

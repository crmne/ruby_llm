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

{{ page.description }}
{: .fs-6 .fw-300 }

After reading this guide, you will know:

* How to read input, output, cache, and thinking token counts from a response.
* How to read per-turn and per-conversation costs.
* How to count a request's tokens before you send it.
* What each token bucket counts.
* How the internal usage ledger accounts for retries, fallbacks, and cancellations.
* How to price token usage yourself with `cost_for` and `Cost.aggregate`.
* How costs are recorded in Rails and how to keep registry pricing fresh.

## Reading Tokens and Costs

Read token counts and costs directly from the response:

```ruby
chat = RubyLLM.chat
response = chat.ask "Explain Ruby blocks."

response.tokens.input
response.tokens.output
response.cost.total

chat.cost.total
```

`response.tokens` is a `RubyLLM::Tokens`; `response.cost` is a `RubyLLM::Cost`. Both are present even when some fields are unknown. Unknown values are `nil`, so a missing price does not look like a free request.

More detailed readers use the same shape:

```ruby
response.tokens.cache_read
response.tokens.cache_write
response.tokens.thinking
response.cost.input
response.cost.output
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

RubyLLM uses token usage from the provider and pricing from the model registry. If the registry is missing pricing for tokens that were used, the affected cost and `cost.total` return `nil` instead of pretending the cost was zero. These helpers cover token-priced conversation usage; provider-specific add-ons such as search-query charges are left to the provider's raw usage payload.

When the provider reports a request's price, `cost.total` uses that amount instead of a registry estimate. Component costs such as `cost.input` still use registry pricing. The same rule applies to [batch costs]({% link _advanced/batches.md %}#cost-and-usage).

[Hosted research]({% link _advanced/hosted-research.md %}) is billed per task. Its cost stays unknown when the service supplies no price, even if it reports zero tokens.

## Counting Tokens Before You Send

Use `RubyLLM.count_tokens` or `chat.count_tokens` to measure chat input before generation. See [Tokenization]({% link _core_features/tokenization.md %}#counting-a-chat-request) for examples and counting limits.

## Tokenizing Plain Text

`RubyLLM.tokenize` returns a model's token IDs for a string. See the [Tokenization guide]({% link _core_features/tokenization.md %}) to inspect text and compare token counts.

## Token Buckets

Token counts use the same meanings across providers:

| Reader | What it counts |
| --- | --- |
| `tokens.input` | Standard input, excluding cache reads and writes. |
| `tokens.output` | Billable output, including thinking when it is billed as output. |
| `tokens.cache_read` | Input served from the prompt cache. |
| `tokens.cache_write` | Input written to the prompt cache. |
| `tokens.thinking` | Thinking tokens, when reported. |

To measure all input activity, add the standard input, cache reads, and cache writes. A missing count is `nil`, so check for it before calculating a total.

Thinking tokens can already be included in `tokens.output`; do not add them again. When a model has distinct thinking-token pricing, `cost.thinking` prices that bucket separately. Otherwise it is part of `cost.output`.

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

When a model publishes a long-context tier, `cost_for` uses those rates once the prompt exceeds the registry threshold. Prompt size is `input + cache_read + cache_write`. Below that threshold, or when the model has no long-context tier, standard rates apply. Batch rates remain unused by `cost_for`; see [Batches]({% link _advanced/batches.md %}).

Most applications use the shorter helpers on messages, chats, and agents: `response.cost.total`, `chat.cost.total`, `agent.cost.total`.

To combine several cost objects yourself, use `RubyLLM::Cost.aggregate`:

```ruby
cost = RubyLLM::Cost.aggregate(messages.map(&:cost))
cost.total
```

If pricing is incomplete for tokens that were used, the affected cost and `cost.total` return `nil`.

## Rails Persistence

With `acts_as_chat`, RubyLLM writes finished attempts to `ruby_llm_usages` immediately. This happens before the message callback, so cancellation cannot erase usage merely because no assistant message was saved.

```ruby
chat = Chat.find(params[:id])
message = chat.messages.last

message.tokens.input
message.cost.total
chat.tokens.input
chat.cost.total
```

The ledger is internal to RubyLLM; your application still owns only its Chat and Message models. Each usage row records the operation, provider, model, status, token buckets, cost components, and timestamps in normalized numeric columns, so ordinary SQL sums and period queries work directly against `ruby_llm_usages`. Costs are frozen at completion, so a later `RubyLLM.models.refresh` that changes registry pricing leaves recorded usage untouched. The upgrade migration moves token counts and frozen costs from pre-2.0 message columns into the ledger and removes those columns, so old and new rows read through the same path.

## Keeping Registry Pricing Fresh

Because recorded costs are frozen at completion, stale registry pricing only affects new attempts, never usage you have already saved. To keep new costs accurate, refresh the registry on a schedule. A daily job is a good default; providers change prices infrequently.

In a Rails app with the database-backed registry, the same refresh call writes the new pricing to RubyLLM's internal model table:

```ruby
# lib/tasks/ruby_llm.rake
namespace :ruby_llm do
  desc 'Refresh the model registry pricing and capabilities'
  task refresh_models: :environment do
    RubyLLM.models.refresh
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

## Next Steps

* [Chat]({% link _core_features/chat.md %}) - the core conversation interface these counts come from.
* [Model Registry]({% link _reference/models.md %}) - explore the registry and the `RubyLLM::Model` pricing fields behind `cost_for`.
* [Extended Thinking]({% link _core_features/thinking.md %}) - work with reasoning-capable models.
* [Instrumentation and Observability]({% link _advanced/instrumentation.md %}) - configure subscribers and custom instrumenters.
* [Persistence with acts_as]({% link _advanced/rails-persistence.md %}) - persist chats while RubyLLM manages the internal ledger.
* [Error Handling]({% link _advanced/error-handling.md %}) - recover from provider failures and configure fallbacks.

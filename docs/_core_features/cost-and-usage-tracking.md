---
layout: default
title: Cost and Usage Tracking
parent: "Chat"
nav_order: 9
description: Track cost and token usage for every provider attempt, including retries and cancellations that never become messages.
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

An LLM transcript is not an accounting ledger. A request can be retried before one response arrives, and a cancelled stream can consume tokens without producing a completed assistant message. Counting messages therefore undercounts real provider work.

RubyLLM records each physical provider attempt internally. This changes the implementation of token and cost helpers without adding a tracking object to the public API.

## The Public API

Token counts always live on a `RubyLLM::Tokens` value, and costs always live on a `RubyLLM::Cost` value. Both objects are present even when a provider does not report every field; unknown fields are `nil`:

```ruby
response = chat.ask("Explain Ruby fibers.")

response.tokens.input
response.tokens.output
response.tokens.cache_read
response.tokens.cache_write
response.tokens.thinking

response.cost.input
response.cost.output
response.cost.total
chat.tokens.input
chat.tokens.output
chat.cost.total
```

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

## What the Aggregates Mean

One response can require several physical attempts. If a transport request fails twice and the third attempt succeeds, the response's `tokens` and `cost` aggregate the reported usage from all three attempts.

Fallbacks work the same way. When an initial model fails and a fallback produces the message, every attempt involved in that logical generation contributes to the resulting message's aggregates.

A cancelled attempt may have no message to attach to. It still contributes to `chat.tokens` and `chat.cost` when RubyLLM has enough reported usage. If an attempt may have been billed but the provider supplied no defensible usage, the token fields for that attempt and `chat.cost.total` are `nil` rather than misleading zeroes. An attempt that provably never reached the provider, such as a refused connection or a failed TLS handshake, records zero tokens instead: it cannot have been billed, so it does not blank the total.

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

The ledger is internal to RubyLLM; your application still owns only its Chat and Message models. Token buckets and cost components use normalized numeric columns rather than a JSON blob. The upgrade migration moves token counts and frozen costs from pre-2.0 message columns into the ledger and removes those columns, so old and new rows read through the same path.

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

* [Token Usage and Cost]({% link _core_features/chat-tokens.md %}) - understand normalized token buckets and provider differences.
* [Instrumentation and Observability]({% link _advanced/instrumentation.md %}) - configure subscribers and custom instrumenters.
* [Persistence with acts_as]({% link _advanced/rails-persistence.md %}) - persist chats while RubyLLM manages the internal ledger.
* [Error Handling]({% link _advanced/error-handling.md %}) - recover from provider failures and configure fallbacks.

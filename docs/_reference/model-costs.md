---
layout: default
title: Model Costs
parent: "Working with Models"
nav_order: 2
description: Turn token usage into a RubyLLM::Cost object and aggregate costs across a conversation
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

*   How to turn a token usage payload into a `RubyLLM::Cost` object with `cost_for`.
*   What normalized token buckets RubyLLM prices and exposes.
*   How to read totals from messages, chats, and agents.
*   How to aggregate several cost objects with `RubyLLM::Cost.aggregate`.
*   When a cost returns `nil` because pricing is incomplete.

## Calculating Costs

Once a model is in the registry, RubyLLM can turn token usage into a `RubyLLM::Cost` object so you can attach a dollar figure to any response.

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

Costs use RubyLLM's normalized token buckets: standard input, billable output, cache read, cache write, and separately priced thinking when the model registry exposes a distinct reasoning-token price. See [Token Usage and Cost]({% link _core_features/chat-tokens.md %}) for the provider comparison table and what RubyLLM exposes consistently across providers.

Most applications use the shorter helpers on messages, chats, and agents:

```ruby
response.cost.total
chat.cost.total
agent.cost.total
```

To combine several cost objects yourself, use `RubyLLM::Cost.aggregate`:

```ruby
cost = RubyLLM::Cost.aggregate(messages.map(&:cost))
cost.total
```

If pricing is incomplete for tokens that were used, the affected cost and `cost.total` return `nil`. Cost helpers cover token-priced conversation usage; provider-specific add-ons such as search-query charges remain available in the provider's raw usage payload.

## Recording Costs in Rails

In a Rails app, `cost_for` prices token usage against the model registry's current pricing every time you call it. Persisted messages can freeze the cost instead. When your messages table has the optional `total_cost` and `cost_details` columns (included in new installs and added by the v2.0 upgrade generator), RubyLLM records each assistant message's cost at completion, and `message.cost` returns that recorded value rather than recomputing it. A later `RubyLLM.models.refresh!` that changes registry pricing then leaves historical costs untouched. See [Rails Persistence]({% link _advanced/rails-persistence.md %}#freezing-costs-at-completion) for the columns and query examples.

## Keeping Registry Pricing Fresh

Because recorded costs are frozen at completion, stale registry pricing only affects the cost of new messages, never messages you have already saved. To keep new costs accurate, refresh the registry on a schedule. A daily job is a good default; providers change prices infrequently.

In a Rails app with the database-backed registry, `Model.refresh!` reloads pricing from the provider APIs and writes it to the `models` table:

```ruby
# lib/tasks/ruby_llm.rake
namespace :ruby_llm do
  desc 'Refresh the model registry pricing and capabilities'
  task refresh_models: :environment do
    Model.refresh!
  end
end
```

Run `bin/rails ruby_llm:refresh_models` from cron, or schedule the `Model.refresh!` call with your background job framework (GoodJob, Sidekiq, or similar). Without the database registry, call `RubyLLM.models.refresh!` directly. RubyLLM does not refresh the registry on its own; you choose the cadence.

## Next Steps

*   [Token Usage and Cost]({% link _core_features/chat-tokens.md %}) - how RubyLLM normalizes token counts across providers.
*   [Working with Models]({% link _reference/models.md %}) - explore the registry and the `RubyLLM::Model` pricing fields behind `cost_for`.

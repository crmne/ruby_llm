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

## Next Steps

*   [Token Usage and Cost]({% link _core_features/chat-tokens.md %}) - how RubyLLM normalizes token counts across providers.
*   [Working with Models]({% link _reference/models.md %}) - explore the registry and the `Model::Info` pricing fields behind `cost_for`.

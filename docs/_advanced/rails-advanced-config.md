---
layout: default
title: Advanced Rails Configuration
parent: "Rails Integration"
nav_order: 4
description: Route models through different providers, use per-tenant contexts, persist raw payloads, and run fiber-safe.
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

*   How to route a model through a different provider per chat.
*   How to use per-tenant API keys with custom contexts.
*   How to create chats for models that aren't in the registry.
*   How to persist raw provider payloads for features like Anthropic prompt caching.
*   How to run ActiveRecord safely inside fiber-based async workloads.

Once the basics are in place, RubyLLM gives you fine-grained control over how persisted chats reach providers. This guide covers the configuration you reach for in production: routing models through alternate providers, isolating credentials per tenant, persisting provider-specific payloads, and keeping ActiveRecord connections correct under async workloads.

## Provider Overrides

Route models through different providers dynamically:

```ruby
chat = Chat.create!(
  model: '{{ site.models.anthropic_current }}',
  provider: 'bedrock'  # Route this model through AWS Bedrock
)

chat.ask("Hello!")
```

## Custom Contexts and Dynamic Models

### Using Custom Contexts

Use different API keys per chat in multi-tenant applications:

**With DB-backed model registry (default in v1.7.0+):**

```ruby
custom_context = RubyLLM.context do |config|
  config.openai_api_key = 'sk-customer-specific-key'
end

chat = Chat.create!(
  model: '{{ site.models.openai_standard }}',
  context: custom_context
)
```

Context is not persisted. Set it after reloading chats.
{: .warning }

```ruby
# Later, in a different request or after restart
chat = Chat.find(chat_id)
chat.context = custom_context  # Must set this!
chat.ask("Continue our conversation")
```

For multi-tenant apps, consider using an `after_find` callback:

```ruby
class Chat < ApplicationRecord
  acts_as_chat
  belongs_to :tenant

  after_find :set_tenant_context

  private

  def set_tenant_context
    self.context = RubyLLM.context do |config|
      config.openai_api_key = tenant.openai_api_key
    end
  end
end
```

### Dynamic Model Creation

When using models not in the registry (e.g., new OpenRouter models), pass `assume_model_exists: true` to skip the registry lookup. See [Model Resolution]({% link _reference/model-resolution.md %}) for exactly how this bypasses the registry:

```ruby
chat = Chat.create!(
  model: 'experimental-llm-v2',
  provider: 'openrouter',
  assume_model_exists: true  # Creates Model record automatically
)
```

Like context, `assume_model_exists` is not persisted.
{: .note }

```ruby
# When switching to another dynamic model later
chat = Chat.find(chat_id)
chat.assume_model_exists = true
chat.with_model('another-experimental-model', provider: 'openrouter')
```

## Working with Raw Provider Payloads, Anthropic Prompt Caching

Providers like Anthropic expose advanced features (prompt caching, fine-grained metadata) by embedding rich structures inside each prompt block. Use `RubyLLM::Content::Raw` to persist those blocks alongside your conversation history:

```ruby
raw_block = RubyLLM::Content::Raw.new([
  { type: 'text', text: 'Reusable analysis prompt', cache_control: { type: 'ephemeral' } },
  { type: 'text', text: "Today's request: #{summary}" }
])

chat = Chat.create!(model: 'claude-sonnet-4-5')
chat.ask(raw_block)
```

The v1.9 schema adds a `content_raw` column so raw payloads live alongside the plain-text `content` field. When you load messages via `acts_as_message`, RubyLLM reconstructs the original `Content::Raw` automatically.

Existing apps: the cached-token and raw-content columns were introduced in v1.9.0. Upgrade one minor version at a time (see the [Upgrading guide]({% link _reference/upgrading.md %})); new apps get the proper columns from the install generator.
{: .note }

## Fiber-Safe ActiveRecord Connections for Async/Fiber Workloads
{: .d-inline-block }

Rails 7.2.1+ / 8.x
{: .label .label-green }

If your app performs database work inside Fibers (for example with async-based workflow stacks), use fiber-safe connection isolation:

```ruby
# config/application.rb
config.active_support.isolation_level = :fiber
```

Why: Rails defaults to thread-based connection isolation. In fiber-heavy flows, that can cause intermittent connection-state issues. `:fiber` scopes ActiveRecord connections per Fiber instead of per Thread.

If you use this setting, prefer Rails versions with fiber isolation fixes (Rails 7.2.1+ / 8.x).
{: .note }

## Instrumentation

Rails apps automatically emit RubyLLM events through `ActiveSupport::Notifications`. See [Instrumentation and Observability]({% link _advanced/instrumentation.md %}) for events, payloads, and non-Rails instrumenters.

## Next Steps

*   [Persistence with acts_as]({% link _advanced/rails-persistence.md %}) - the models these configurations apply to.
*   [Scale with Async]({% link _advanced/async.md %}) - run concurrent, fiber-based workloads at scale.
*   [Instrumentation and Observability]({% link _advanced/instrumentation.md %}) - monitor and trace RubyLLM in production.
*   [Token Usage and Cost]({% link _core_features/chat-tokens.md %}) - the full token and cost reference.

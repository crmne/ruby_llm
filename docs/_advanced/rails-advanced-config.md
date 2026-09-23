---
layout: default
title: Advanced Rails Configuration
parent: "Rails Integration"
nav_order: 4
description: Route models through different providers, use per-tenant contexts, persist cache boundaries, adjust provider payloads per request, and run fiber-safe.
---

# {{ page.title }}

{{ page.description }}
{: .fs-6 .fw-300 }

After reading this guide, you will know:

*   How to keep chats and RubyLLM's supporting tables on a secondary database.
*   How to route a model through a different provider per chat.
*   How to use per-tenant API keys with custom contexts.
*   How to create chats for models that aren't in the registry.
*   How to persist cache boundaries and adjust provider payloads per request.
*   How to run ActiveRecord safely inside fiber-based async workloads.

Persisted chats use the same configuration methods as plain Ruby. Use them to select a provider, isolate tenant credentials, or set cache boundaries on a conversation.

## Using a Secondary Database

When your chats and messages use another database, configure `RubyLLM::ActiveRecord::Record` to share their connection pool:

```ruby
# config/initializers/ruby_llm_database.rb
Rails.application.config.to_prepare do
  RubyLLM::ActiveRecord::Record.connection_specification_name =
    LlmRecord.connection_specification_name
end
```

Here, `LlmRecord` is your application's abstract class for that database. Your chat and message classes inherit from it:

```ruby
# app/models/llm_record.rb
class LlmRecord < ApplicationRecord
  self.abstract_class = true
  connects_to database: { writing: :llm }
end

# app/models/chat.rb
class Chat < LlmRecord
  acts_as_chat
end

# app/models/message.rb
class Message < LlmRecord
  acts_as_message
end
```

This uses the `llm` entry in `config/database.yml`. Set its `migrations_paths` to a dedicated directory, such as `db/llm_migrate`. See the [Rails multiple databases guide](https://guides.rubyonrails.org/active_record_multiple_databases.html) for database configuration.

For a new installation, move the three RubyLLM migrations from `db/migrate` to that directory before running them. Keep the migration order: RubyLLM's supporting tables, chats, then messages. Run:

```bash
bin/rails db:migrate:llm
bin/rails ruby_llm:load_models
```

The install generator uses the default database's adapter when generating migrations. If the secondary database uses another adapter, adjust the generated column types and indexes for that adapter before migrating. Configuring the record connection does not move existing tables or data, or redirect install and upgrade migrations automatically.

Keep chats, messages, and all four `ruby_llm_` tables in the same database. The generated chat table has a foreign key to `ruby_llm_models`. Sharing the connection pool also makes writes to these records participate in the same transaction. Calling `connects_to` separately on two abstract classes creates separate pools, even when both point to the same database.

You can also call `RubyLLM::ActiveRecord::Record.connects_to database: { writing: :llm }` directly when your chat and message classes inherit from `RubyLLM::ActiveRecord::Record`. This gives them and RubyLLM's supporting records one shared pool. Use the application-owned base above when you need to retain behavior from `ApplicationRecord`.

This configuration selects one database for RubyLLM's supporting records. It does not route them independently for chat classes stored in different databases.

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
  model: ENV.fetch("OPENROUTER_MODEL"),
  provider: 'openrouter',
  assume_model_exists: true  # Skips registry validation
)
```

Like context, `assume_model_exists` is not persisted.
{: .note }

```ruby
# When switching to another dynamic model later
chat = Chat.find(chat_id)
chat.with_model(ENV.fetch("OPENROUTER_FALLBACK_MODEL"), provider: 'openrouter', assume_model_exists: true)
```

## Working with Prompt Caching

Prompt caching configuration is applied to the underlying LLM chat, and explicit boundaries are persisted on messages. Mark the stable part of the conversation, then continue normally:

```ruby
chat = Chat.create!(model: 'claude-sonnet-4-5')
chat.with_caching(ttl: "1h")
chat.with_instructions('Reusable analysis prompt').cache_until_here
chat.add_message(role: :user, content: long_context).cache_until_here
chat.ask("Today's request: #{summary}")
```

Existing apps get `cache_until_here` and the other current persistence columns by following [Upgrading]({% link _reference/upgrading.md %}) for each release. New apps get the proper columns from the install generator.
{: .note }

When the stable prefix should not be stored with the transcript, disable persistence. This is useful for an application-wide policy followed by tenant or request context:

```ruby
chat.with_caching
chat.with_instructions(stable_policy, persist: false, cache_until_here: true)
chat.with_instructions(current_context, append: true, persist: false)
```

Unpersisted instructions are not written to the message table. They and their cache boundary remain configured when you call `reload` on the same record instance. Reapply them after finding the record in another process, or declare them with `persist: false` on a RubyLLM agent so `Agent.find` does that for you.

See [Prompt Caching]({% link _core_features/prompt-caching.md %}) for provider behavior.

## Working with Provider-Specific Payloads

Message content is always text: what you persist is the conversation, not a provider's wire format. When a request needs provider-specific blocks RubyLLM has not wrapped, use a [`before_request` hook]({% link _core_features/chat-request-control.md %}#request-hooks); it adjusts the rendered payload per request and stores nothing.

## Fiber-Safe ActiveRecord Connections for Async/Fiber Workloads
{: .d-inline-block }

Rails 7.2.1+ / 8.x
{: .label .label-green }

If your app uses [Solid Queue fiber workers]({% link _advanced/async.md %}#background-jobs-with-solid-queue) or runs database work inside Async tasks, enable fiber isolation:

```ruby
# config/application.rb
config.active_support.isolation_level = :fiber
```

Rails defaults to thread-scoped execution state. `:fiber` keeps that state, including Active Record connections, separate for each fiber. This setting applies to the whole application; Solid Queue requires it before starting fiber workers.

If you use this setting, prefer Rails versions with fiber isolation fixes (Rails 7.2.1+ / 8.x).
{: .note }

## Instrumentation

Rails apps automatically emit RubyLLM events through `ActiveSupport::Notifications`. See [Instrumentation and Observability]({% link _advanced/instrumentation.md %}) for events, payloads, and non-Rails instrumenters.

## Next Steps

*   [Persistence with acts_as]({% link _advanced/rails-persistence.md %}) - the models these configurations apply to.
*   [Scale with Async]({% link _advanced/async.md %}) - run concurrent, fiber-based workloads at scale.
*   [Instrumentation and Observability]({% link _advanced/instrumentation.md %}) - monitor and trace RubyLLM in production.
*   [Tokens and Costs]({% link _core_features/cost-and-usage-tracking.md %}) - the full token and cost reference.

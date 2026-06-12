---
layout: default
title: Upgrading
nav_order: 7
description: Upgrade guides for changes in data formats
redirect_from:
  - /upgrading-to-1-7
  - /upgrading-to-1-7/
---

# {{ page.title }}
{: .no_toc }

{{ page.description }}
{: .fs-6 .fw-300 }

## Table of contents
{: .no_toc .text-delta }

1. TOC
{:toc}

This guide focuses on upgrade-impacting changes: migrations, token semantics, deprecations, and compatibility notes. It is not a complete changelog. For every feature, fix, and patch note, see the [GitHub releases](https://github.com/crmne/ruby_llm/releases).
{: .note }

---
# Upgrade to 2.0

## How to Upgrade

```bash
# Run the upgrade generator
bin/rails generate ruby_llm:upgrade_to_v2_0

# Run migrations
bin/rails db:migrate
```

The generator adds a JSON `citations` column to your messages table so [citations]({% link _core_features/citations.md %}) are persisted with each assistant message. The column is optional — without it, citations remain available on in-memory responses but aren't saved.

## Providers and Protocols Split

RubyLLM 2.0 separates providers (host, auth, catalog) from protocols (wire format). The public chat API is unchanged — `RubyLLM.chat`, `with_params`, `embed`, `paint`, and the Rails integration all work as before. Two things changed underneath:

**OpenAI now defaults to the Responses API.** This unlocks reasoning models with tools and extended thinking together. To stay on Chat Completions:

```ruby
RubyLLM.configure do |config|
  config.openai_protocol = :chat_completions
end

# or per chat
RubyLLM.chat(model: 'gpt-5.4').with_protocol(:chat_completions)
```

If you pass Chat Completions–only params via `with_params` (like `response_format`), either switch those chats to `:chat_completions` or use the Responses API equivalents (`text: { format: ... }`).

**Wire-format internals moved to `RubyLLM::Protocols`.** `RubyLLM::Providers::OpenAI::Chat` and sibling modules are now `RubyLLM::Protocols::ChatCompletions::Chat` and friends; Anthropic, Gemini, and Bedrock Converse internals moved the same way. Provider classes no longer inherit from each other (`Mistral < OpenAI` is gone) — a provider declares its protocols instead.

If you maintain a provider gem, subclass a protocol for your dialect and declare it in a thin provider:

```ruby
class MyProvider < RubyLLM::Provider
  class ChatCompletions < RubyLLM::Protocols::ChatCompletions
    # your overrides
  end

  protocol :chat_completions, ChatCompletions
end
```

For routing details and per-chat overrides, see [Choosing the Wire Protocol]({% link _core_features/chat.md %}#choosing-the-wire-protocol).

---
# Upgrade to 1.15

## How to Upgrade

No generator is required for the token and cost API changes in 1.15.

If you use the Rails integration and already ran the v1.9 migration, no new columns are needed. The new `cache_read_tokens` and `cache_write_tokens` helpers use the existing `cached_tokens` and `cache_creation_tokens` columns.

## Token Semantics Changed

RubyLLM now normalizes prompt cache usage before exposing token counts. From 1.15 onward, `response.tokens.input` means standard input tokens. When a provider includes cache reads or cache writes in its raw prompt token total, RubyLLM subtracts those cache buckets and exposes them separately.

Use the new cache names in new code:

```ruby
response.tokens.input
response.tokens.output
response.tokens.cache_read
response.tokens.cache_write
```

The top-level token helpers still work for backwards compatibility:

```ruby
response.input_tokens       # Same as tokens.input
response.output_tokens      # Same as tokens.output
response.cache_read_tokens  # Same as tokens.cache_read
response.cache_write_tokens # Same as tokens.cache_write
response.cached_tokens          # Same as cache_read_tokens
response.cache_creation_tokens  # Same as cache_write_tokens
```

If your app stored or displayed provider raw prompt totals, reconstruct the request-side input activity by adding the normalized buckets:

```ruby
request_side_input_tokens =
  response.tokens.input.to_i +
  response.tokens.cache_read.to_i +
  response.tokens.cache_write.to_i
```

For costs, prefer the new cost helpers instead of multiplying token totals yourself:

```ruby
response.cost.total
chat.cost.total
agent.cost.total
```

Cost helpers are available from 1.15 onward. They return `nil` for any cost bucket whose pricing is missing, and `cost.total` is also `nil` when a used bucket has incomplete pricing.

`tokens.thinking` remains available from 1.10. From 1.15 onward, `tokens.output` is normalized as the billable output bucket. Do not add `tokens.thinking` to `tokens.output` yourself; RubyLLM includes thinking in output when the provider bills it as output, and exposes `cost.thinking` only for models with distinct reasoning-token pricing.

See [Tracking Token Usage]({% link _core_features/chat.md %}#tracking-token-usage) for the provider comparison table and the exact normalized token semantics RubyLLM exposes.

# Upgrade to 1.14

## How to Upgrade

```bash
# Run the upgrade generator
bin/rails generate ruby_llm:upgrade_to_v1_14

# Run migrations
bin/rails db:migrate
```

That's it! The generator:
- Changes `thought_signature` on tool calls from `string` to `text`
- Prevents thought signature truncation issues on MySQL/MariaDB

## What's New in 1.14

Among other features:

- Safer Gemini thought signature persistence for Rails apps using ActiveRecord

# Upgrade to 1.10

## How to Upgrade

```bash
# Run the upgrade generator
bin/rails generate ruby_llm:upgrade_to_v1_10

# Run migrations
bin/rails db:migrate
```

That's it! The generator:
- Adds `thinking_text` and `thinking_signature` for storing extended thinking output
- Adds `thinking_tokens` for tracking thinking token usage
- Adds `thought_signature` to tool calls for Gemini 3 Pro function calling

## What's New in 1.10

Among other features:

- Extended thinking support across providers with optional persistence
- Thinking token tracking when providers report it

# Upgrade to 1.9

## How to Upgrade

```bash
# Run the upgrade generator
bin/rails generate ruby_llm:upgrade_to_v1_9

# Run migrations
bin/rails db:migrate
```

That's it! The generator:
- Adds the `cached_tokens` and `cache_creation_tokens` columns for tracking accessed cached tokens and created cache tokens respectively.
- Adds the `content_raw` column for the new [Raw Content Blocks]({% link _core_features/chat.md %}#raw-content-blocks) feature

## What's New in 1.9

Among other features:

- [Raw Content Blocks]({% link _core_features/chat.md %}#raw-content-blocks) to pass content verbatim to an LLM, e.g. useful to enable Anthropic Prompt Caching.
- Cached token tracking to accurately track costs given cache hits

# Upgrade to 1.7

Upgrade to the DB-backed model registry for better data integrity and rich model metadata.

## How to Upgrade

### From 1.6 to 1.7 (2 commands)

```bash
# Run the upgrade generator
bin/rails generate ruby_llm:upgrade_to_v1_7

# Run migrations
bin/rails db:migrate
```

That's it! The generator:
- Creates the models table if needed
- Automatically adds `config.use_new_acts_as = true` to your initializer
- Automatically updates your existing models' `acts_as` declarations to the new version
- Migrates your existing data to use foreign keys
- Loads the models in the db
- Preserves all your data (old string columns renamed to `model_id_string`)

### Custom Model Names

If you're using custom model names:

```bash
bin/rails generate ruby_llm:upgrade_to_v1_7 chat:Conversation message:ChatMessage tool_call:MyToolCall model:MyModel
bin/rails db:migrate
```

### What happens without upgrading

Your existing 1.6 app continues working without any changes. You'll see a deprecation warning on Rails boot:

```
!!! RubyLLM's legacy acts_as API is deprecated and will be removed in RubyLLM 2.0.0.
```

You can silence or raise RubyLLM deprecations while upgrading:

```ruby
RubyLLM.configure do |config|
  config.deprecation_behavior = :silence # or :raise
end
```

## What's New in 1.7

Among other features, the DB-backed model registry replaces simple string fields with proper ActiveRecord associations. Additionally, the `acts_as` helpers have been redesigned with a more Rails-like API.

### Available with DB-backed Model Registry
{: .d-inline-block }

v1.7.0+
{: .label .label-green }

**New Rails-like `acts_as` API**
```ruby
# New API uses Rails association names as primary parameters
acts_as_chat messages: :messages, model: :model
acts_as_message chat: :chat, tool_calls: :tool_calls, model: :model

# vs Legacy API which required explicit class names
acts_as_chat message_class: 'Message', tool_call_class: 'ToolCall'
acts_as_message chat_class: 'Chat', chat_foreign_key: 'chat_id'
```

**Rich model metadata**
```ruby
chat.model.name              # => "GPT-4"
chat.model.context_window    # => 128000
chat.model.supports_vision   # => true
chat.model.input_token_cost  # => 2.50
```

**Provider routing**
```ruby
Chat.create!(model: "{{ site.models.anthropic_current }}", provider: "bedrock")
```

**Model associations and queries**
```ruby
Chat.joins(:model).where(models: { provider: 'anthropic' })
Model.select { |m| m.supports_functions? }  # Use delegated methods
```

**Model alias resolution**
```ruby
Chat.create!(model: "{{ site.models.default_chat }}", provider: "openrouter")  # Resolves to openai/{{ site.models.default_chat }} automatically
```

**Usage tracking**
```ruby
Model.joins(:chats).group(:id).order('COUNT(chats.id) DESC')
```

### Available without Model Registry
{: .d-inline-block }

Legacy mode
{: .label .label-yellow }

**Legacy `acts_as` API** - Still uses the old parameter style
```ruby
acts_as_chat message_class: 'Message', tool_call_class: 'ToolCall'
acts_as_message chat_class: 'Chat', tool_call_class: 'ToolCall'
```

**Basic functionality** - All core RubyLLM features work
```ruby
chat.ask("Hello!")  # Works fine
chat.model_id  # => "{{ site.models.openai_standard }}" (string only, no metadata)
```

**Limited to:**
- String-based model IDs only
- Default provider routing

## If You Have Custom Model Names

If you're using custom model names (e.g., `Conversation` instead of `Chat`), you may need to update your `acts_as` declarations to the new API:

**Before (1.6):**
```ruby
class Conversation < ApplicationRecord
  acts_as_chat message_class: 'ChatMessage', tool_call_class: 'AiToolCall'
end

class ChatMessage < ApplicationRecord
  acts_as_message chat_class: 'Conversation', chat_foreign_key: 'conversation_id'
end
```

**After (1.7):**
```ruby
class Conversation < ApplicationRecord
  acts_as_chat messages: :chat_messages  # Association name
end

class ChatMessage < ApplicationRecord
  acts_as_message chat: :conversation,  # Association name
                  tool_calls: :ai_tool_calls
end
```

The new API follows Rails association inference. Association names determine default foreign keys; class options only change the class name. For example, `tool_calls: :ai_tool_calls` uses `ai_tool_call_id`, while `tool_call_class: 'AiToolCall'` by itself still uses `tool_call_id`.

## New Chat UI Generator

### Instant Chat Interface
{: .d-inline-block }

v1.7.0+
{: .label .label-green }

Add a fully-functional chat UI to your Rails app with Turbo streaming:

```bash
# Default model names
bin/rails generate ruby_llm:chat_ui

# Or with custom model names (same as install generator)
bin/rails generate ruby_llm:chat_ui chat:Conversation message:ChatMessage model:LLMModel
```

This creates:
- Complete chat controller with streaming responses
- Turbo-powered views with real-time updates
- Styled chat interface (messages, input, model selector)
- File attachment support
- Token usage tracking
- Copy-to-clipboard functionality

The chat UI works with your existing Chat and Message models and includes:
- Model selection dropdown
- Real-time streaming responses
- Markdown rendering
- Code syntax highlighting
- Responsive design

## Troubleshooting

### Config must be set before models load

If you're setting `use_new_acts_as = true` in an initializer (like `config/initializers/ruby_llm.rb`), it won't work. Rails loads models before initializers run, causing various issues:

**Symptoms:**
- Legacy `acts_as` module gets included even though you set `use_new_acts_as = true`
- `undefined local variable or method 'acts_as_model'` error during migration
- Errors referencing `lib/ruby_llm/active_record/acts_as_legacy.rb` in backtraces
- Works in development/staging but fails in production

**Solution:**

Add the configuration to `config/application.rb` **before** your Application class:

```ruby
# config/application.rb
require_relative "boot"
require "rails/all"

# Configure RubyLLM before Rails::Application is inherited
RubyLLM.configure do |config|
  config.use_new_acts_as = true
end

module YourApp
  class Application < Rails::Application
    # ...
  end
end
```

This ensures RubyLLM is configured before ActiveRecord loads your models. Other configuration options (API keys, timeouts, etc.) can still go in your initializer.

> This limitation exists because both legacy and new `acts_as` APIs need to coexist during the 1.x series. It will be resolved in RubyLLM 2.0 when the legacy API is removed.
{: .note }

See the [Configuration guide]({% link _getting_started/configuration.md %}#initializer-load-timing-issue-with-use_new_acts_as) for more details.

## New Applications

Fresh installs get the model registry automatically:

```bash
bin/rails generate ruby_llm:install
bin/rails db:migrate

# Optional: Add chat UI
bin/rails generate ruby_llm:chat_ui
```

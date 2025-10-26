---
layout: default
title: Upgrading
nav_order: 6
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

---
# Upgrade to 1.9

## How to Upgrade

```bash
# Run the upgrade generator
rails generate ruby_llm:upgrade_to_v1_9

# Run migrations
rails db:migrate
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
rails generate ruby_llm:upgrade_to_v1_7

# Run migrations
rails db:migrate
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
rails generate ruby_llm:upgrade_to_v1_7 chat:Conversation message:ChatMessage tool_call:MyToolCall model:MyModel
rails db:migrate
```

### What happens without upgrading

Your existing 1.6 app continues working without any changes. You'll see a deprecation warning on Rails boot:

```
!!! RubyLLM's legacy acts_as API is deprecated and will be removed in RubyLLM 2.0.0.
```

## What's New in 1.7

Among other features, the DB-backed model registry replaces simple string fields with proper ActiveRecord associations. Additionally, the `acts_as` helpers have been redesigned with a more Rails-like API.

### Available with DB-backed Model Registry
{: .d-inline-block }

v1.7.0+
{: .label .label-green }

**New Rails-like `acts_as` API**
```ruby
# New API uses association names as primary parameters
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
  acts_as_chat message_class: 'ChatMessage', tool_call_class: 'AIToolCall'
end

class ChatMessage < ApplicationRecord
  acts_as_message chat_class: 'Conversation', chat_foreign_key: 'conversation_id'
end
```

**After (1.7):**
```ruby
class Conversation < ApplicationRecord
  acts_as_chat messages: :chat_messages,  # Association name
               message_class: 'ChatMessage'  # Class name if not inferrable
end

class ChatMessage < ApplicationRecord
  acts_as_message chat: :conversation,  # Association name
                  chat_class: 'Conversation'  # Class name if not inferrable
end
```

## New Chat UI Generator

### Instant Chat Interface
{: .d-inline-block }

v1.7.0+
{: .label .label-green }

Add a fully-functional chat UI to your Rails app with Turbo streaming:

```bash
# Default model names
rails generate ruby_llm:chat_ui

# Or with custom model names (same as install generator)
rails generate ruby_llm:chat_ui chat:Conversation message:ChatMessage model:LLMModel
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
rails generate ruby_llm:install
rails db:migrate

# Optional: Add chat UI
rails generate ruby_llm:chat_ui
```

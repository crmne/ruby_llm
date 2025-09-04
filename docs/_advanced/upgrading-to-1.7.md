---
layout: default
title: Upgrading to 1.7
nav_order: 6
description: Upgrade to the DB-backed model registry for better data integrity and rich model metadata.
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

## What's New in 1.7

Among other features, the DB-backed model registry replaces simple string fields with proper ActiveRecord associations.

### Available with DB-backed Model Registry (1.7+)

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

### Available without Model Registry (<1.7 or legacy mode)

**Basic functionality** - All core RubyLLM features work
```ruby
chat.ask("Hello!")  # Works fine
chat.model_id  # => "{{ site.models.openai_standard }}" (string only, no metadata)
```

**Limited to:**
- String-based model IDs only
- Default provider routing

## Upgrading from 1.6

### Your App Continues Working

Without any changes, your 1.6 app continues to work with string fields. You'll see a deprecation warning on Rails boot.

### Migrate to Model Registry (Recommended)

```bash
rails generate ruby_llm:install
rails generate ruby_llm:migrate_model_fields
rails db:migrate
```

Then enable it in your initializer:

```ruby
# config/initializers/ruby_llm.rb
RubyLLM.configure do |config|
  config.model_registry_class = "Model"
end
```

That's it! The migration:
- Creates the models table
- Loads all models from models.json automatically
- Migrates your existing data to use foreign keys
- Preserves everything (renames old columns to `model_id_string`)

## New Applications

Fresh installs get the model registry automatically:

```bash
rails generate ruby_llm:install
rails db:migrate
```

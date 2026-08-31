---
layout: default
title: Working with Models
nav_order: 1
has_children: true
description: Access hundreds of AI models from all major AI providers with one Ruby framework
redirect_from:
  - /guides/models
---

# {{ page.title }}

{{ page.description }}
{: .fs-6 .fw-300 }

After reading this guide, you will know:

*   How RubyLLM discovers and registers models.
*   How RubyLLM selects and refreshes the bundled, cached, or database registry.
*   How to find and filter available models by provider, type, or capabilities.
*   What `RubyLLM::Model` exposes about a model's capabilities and pricing.
*   How to use model aliases and resolve the same alias across providers.

## The Model Registry

RubyLLM maintains a registry of known AI models. Every gem includes a snapshot so a new installation works immediately. The latest published registry is also available at [`https://rubyllm.com/models.json`](https://rubyllm.com/models.json).

In plain Ruby, RubyLLM uses the valid registry in your operating system's user cache when it exists, otherwise it uses the bundled snapshot. In Rails applications, RubyLLM stores the registry in its internal `ruby_llm_models` table. Once that table has rows it is authoritative; while it is empty, RubyLLM falls back to the registry file, then to the bundled snapshot.

The registry stores crucial information about each model, including:

*   **`id`**: The unique identifier used by the provider (e.g., `gpt-4o-2024-08-06`).
*   **`provider`**: The source provider (`openai`, `anthropic`, etc.).
*   **`type`**: The model's primary function (`chat`, `embedding`, etc.).
*   **`name`**: A human-friendly name.
*   **`context_window`**: Max input tokens (e.g., `128_000`).
*   **`max_output_tokens`**: Max output tokens (e.g., `16_384`).
*   **`supports?(:vision)`**: If it can process images and videos.
*   **`supports?(:function_calling)`**: If it can use [Tools]({% link _core_features/tools.md %}).
*   **`price(:input)`**: Cost in USD per 1 million input tokens.
*   **`price(:output)`**: Cost in USD per 1 million output tokens.
*   **`price(:cache_read)`**: Cost in USD per 1 million cache read tokens, when available.
*   **`price(:cache_write)`**: Cost in USD per 1 million cache write tokens, when available.
*   **`family`**: A broader classification (e.g., `claude-sonnet`).

This registry allows RubyLLM to validate models, route requests correctly, provide capability information, and offer convenient filtering.

You can see the full list of currently registered models in the [Available Models Guide]({% link _reference/available-models.md %}).

## Refreshing the Registry

Refresh models everywhere with one call:

```ruby
RubyLLM.models.refresh
```

The call has the same meaning in every environment. It replaces the in-memory registry and persists it to the active store: the platform cache in plain Ruby or RubyLLM's internal model table with the Active Record integration. You do not need a second save call.

RubyLLM does not refresh automatically. Network access and provider credentials remain explicit application concerns, and a missing-model lookup never triggers network I/O.

### How refresh Works

The `refresh` method performs the following steps:

1. **Fetches the published catalog**: Downloads the current registry from rubyllm.com, using its ETag when a file cache is active.
2. **Discovers configured providers**: Queries configured provider APIs, including local providers by default.
3. **Merges the data**: Keeps the published metadata while adding provider-specific or local discoveries.
4. **Persists the result**: Atomically replaces the file cache, or updates RubyLLM's internal Active Record table inside a transaction.

The method returns a chainable `Models` instance, allowing you to immediately query the updated registry:

```ruby
chat_models = RubyLLM.models.refresh.chat_models
```

The published registry is generated from provider APIs and [models.dev](https://models.dev). A failed refresh raises `RubyLLM::ModelRegistryError` and leaves the previously loaded registry available.

### Local Provider Models

By default, `refresh` includes models from local providers like Ollama and GPUStack if they're configured. To exclude local providers and only fetch from remote APIs:

```ruby
RubyLLM.models.refresh(remote_only: true)
```

### Cache Location

The default plain Ruby cache locations are:

* Linux: `$XDG_CACHE_HOME/ruby_llm/models.json`, or `~/.cache/ruby_llm/models.json`
* macOS: `~/Library/Caches/RubyLLM/models.json`
* Windows: `%LOCALAPPDATA%\RubyLLM\Cache\models.json`

Set `config.model_registry_file` to use another writable path. See [Connection, Logging and Contexts]({% link _getting_started/configuration-connection.md %}#model-registry-file).

`refresh` already saves to the active registry store. Use `save_to_json` separately when you want to export the currently loaded registry to another file:

```ruby
RubyLLM.models.save_to_json('/tmp/models.json')
```

### For Gem Maintainers

The source repository includes a maintainer-only task that builds a registry directly from provider APIs and models.dev:

```bash
bundle exec rake models:update
```

These tasks live outside the gem's packaged Rake task directory. They are not application commands and are intentionally unavailable after installing the gem.

### Rails Database Registry

For Rails applications, the install generator sets up everything automatically:

```bash
bin/rails generate ruby_llm:install
bin/rails db:migrate
```

This creates RubyLLM's internal model table. Load or refresh it with the same public entry point used by plain Ruby:

```ruby
RubyLLM.models.refresh
```

### When a Model Disappears

A refresh reports the models your configured provider lists today, so a model you used yesterday can be missing tomorrow, and looking it up raises `RubyLLM::ModelNotFoundError`.

RubyLLM does not guess what you meant by a model it cannot find. Deciding what happens next is application logic, because only your application knows whether an old conversation should move to a successor model, fall back to a different provider, or stop and tell the person using it.

Handle the lookup where you resolve a model:

```ruby
def chat_for(record)
  record.to_llm
rescue RubyLLM::ModelNotFoundError
  record.with_model('{{ site.models.anthropic_current }}')
end
```

Or migrate the records once, after a refresh:

```ruby
Chat.where(model_id: 'claude-3-opus-20240229').find_each do |chat|
  chat.with_model('claude-opus-4-5')
end
```

For a chat that should survive on its own, configure fallbacks so the request moves to the next model instead of raising. See [Advanced Request Control]({% link _core_features/chat-request-control.md %}).

In Rails, a refresh deletes the rows for the models the provider no longer lists. A row one of your chats points at cannot go: the chat's foreign key holds it there. RubyLLM keeps that row, stamps it with `unlisted_at`, and logs one warning per refresh naming the models it kept.

RubyLLM calls those models unlisted, not retired, because a refresh only tells it what the provider listed. A provider that dropped a model and a provider that serves a different catalog in your configured region look the same from here. Vertex AI lists `gemini-embedding-001` in `us-central1` but not in `global`, and `gemini-2.0-flash-001` the other way around.

Listing methods leave unlisted models out. `RubyLLM.models.all`, `chat_models`, `by_provider`, and the rest report what the provider lists, so a picker built from them never offers a model that has gone away:

```ruby
RubyLLM.models.chat_models
```

Resolving by id does not. `find` still returns an unlisted model, so the chats that point at one keep working:

```ruby
RubyLLM.models.find('claude-3-opus-20240229')  # resolves while the row is there
Chat.last.to_llm                               # so an old chat does not raise
```

It is a model you name directly, in code or in a form, that raises once its row is gone.

The `unlisted` scope drives the migration pass after a refresh:

```ruby
RubyLLM.models.refresh

RubyLLM::ActiveRecord::Model.unlisted.find_each do |model|
  Chat.where(model: model).find_each do |chat|
    chat.with_model('claude-opus-4-5')
  end
end
```

`RubyLLM.models.unlisted` reports the same models from the registry, as `RubyLLM::Model` entries.

Once nothing references an unlisted model, the next refresh deletes its row. A model the provider lists again loses its `unlisted_at` on the refresh that carries it.

Only the Rails registry keeps unlisted models. The registry file and the published `models.json` hold what the last refresh returned, so an unlisted model is not in them at all.

## Exploring and Finding Models

Use `RubyLLM.models` to explore the registry.

### Listing and Filtering

```ruby
all_models = RubyLLM.models.all

chat_models = RubyLLM.models.chat_models
embedding_models = RubyLLM.models.embedding_models

openai_models = RubyLLM.models.by_provider(:openai) # or 'openai'

# Filter by model family (e.g., all Claude Sonnet variants)
claude_sonnet_family = RubyLLM.models.by_family('claude-sonnet')

# Chain filters and use Enumerable methods
openai_vision_models = RubyLLM.models.by_provider(:openai)
                                   .select { |model| model.supports?(:vision) }

puts "Found #{openai_vision_models.count} OpenAI vision models."
```

### Finding a Specific Model

Use `find` to get a `RubyLLM::Model` object containing details about a specific model.

```ruby
model_info = RubyLLM.models.find('{{ site.models.openai_tools }}')

puts "Model: #{model_info.name}"
puts "Provider: #{model_info.provider}"
puts "Context Window: #{model_info.context_window} tokens"

# Find raises ModelNotFoundError if the ID is unknown
# RubyLLM.models.find('no-such-model-exists') # => raises ModelNotFoundError
```

### Model Aliases

RubyLLM uses aliases (defined in `lib/ruby_llm/aliases.json`) for convenience, mapping common names to specific versions.

```ruby
# 'claude-opus-4' maps to the dated release ID
chat = RubyLLM.chat(model: 'claude-opus-4')
puts chat.model.id # => "claude-opus-4-20250514"
```

When you call `find` without a provider, RubyLLM resolves the alias and then picks the most preferred provider that carries the model (first-party providers before aggregators). See [Model Resolution]({% link _reference/model-resolution.md %}) for the full procedure.

### Provider-Specific Resolution

Specify the provider if the same alias exists across multiple providers.

```ruby
model_anthropic = RubyLLM.models.find('{{ site.models.anthropic_current }}', :anthropic)

model_bedrock = RubyLLM.models.find('{{ site.models.anthropic_current }}', :bedrock)
```

When you pass a provider, RubyLLM resolves aliases first. For Bedrock, it then applies region/inference-profile resolution (for example `us.` prefixes) before falling back to an exact ID match. See [Model Resolution]({% link _reference/model-resolution.md %}) for the exact order, step by step.

## Next Steps

*   [Tokens and Costs]({% link _core_features/cost-and-usage-tracking.md %}) - turn token usage into a `RubyLLM::Cost` object and aggregate costs across messages.
*   [Custom Endpoints and Unlisted Models]({% link _reference/custom-endpoints.md %}) - target OpenAI-compatible endpoints and use model IDs the registry doesn't list.
*   [Available Models]({% link _reference/available-models.md %}) - browse every model currently registered with RubyLLM.

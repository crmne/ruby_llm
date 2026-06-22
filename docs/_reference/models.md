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
{: .no_toc }

{{ page.description }}
{: .fs-6 .fw-300 }

## Table of contents
{: .no_toc .text-delta }

1. TOC
{:toc}

---

After reading this guide, you will know:

*   How RubyLLM discovers and registers models.
*   How to refresh the registry from provider APIs and persist it to disk.
*   How to find and filter available models by provider, type, or capabilities.
*   What `Model::Info` exposes about a model's capabilities and pricing.
*   How to use model aliases and resolve the same alias across providers.

## The Model Registry

RubyLLM maintains an internal registry of known AI models, typically stored in `lib/ruby_llm/models.json` within the gem. This registry is populated by running the `rake models:update` task, which queries the APIs of configured providers to discover their available models and capabilities.

The registry stores crucial information about each model, including:

*   **`id`**: The unique identifier used by the provider (e.g., `gpt-4o-2024-08-06`).
*   **`provider`**: The source provider (`openai`, `anthropic`, etc.).
*   **`type`**: The model's primary function (`chat`, `embedding`, etc.).
*   **`name`**: A human-friendly name.
*   **`context_window`**: Max input tokens (e.g., `128_000`).
*   **`max_tokens`**: Max output tokens (e.g., `16_384`).
*   **`supports_vision`**: If it can process images and videos.
*   **`supports_functions`**: If it can use [Tools]({% link _core_features/tools.md %}).
*   **`input_price_per_million`**: Cost in USD per 1 million input tokens.
*   **`output_price_per_million`**: Cost in USD per 1 million output tokens.
*   **`cache_read_input_price_per_million`**: Cost in USD per 1 million cache read tokens, when available. v1.15+
*   **`cache_write_input_price_per_million`**: Cost in USD per 1 million cache write tokens, when available. v1.15+
*   **`family`**: A broader classification (e.g., `gpt4o`).

This registry allows RubyLLM to validate models, route requests correctly, provide capability information, and offer convenient filtering.

You can see the full list of currently registered models in the [Available Models Guide]({% link _reference/available-models.md %}).

## Refreshing the Registry

**For Application Developers:**

The recommended way to refresh models in your application is to call `RubyLLM.models.refresh!` directly:

```ruby
RubyLLM.models.refresh!
puts "Refreshed in-memory model list."
```

This refreshes the in-memory model registry and is what you want 99% of the time. This method is safe to call from Rails applications, background jobs, or any running Ruby process.

**Important:** `refresh!` only updates the in-memory registry. To persist changes to disk, call:

```ruby
RubyLLM.models.refresh!
RubyLLM.models.save_to_json  # Saves to configured model_registry_file (v1.9.0+)
```

If your gem directory is read-only, configure a writable location with `config.model_registry_file` (v1.9.0+). See the [Connection, Logging and Contexts Guide]({% link _getting_started/configuration-connection.md %}#model-registry-file) for details.

**How refresh! Works:**

The `refresh!` method performs the following steps:

1. **Fetches from configured providers**: Queries the APIs of all configured providers (OpenAI, Anthropic, Ollama, etc.) to get their current list of available models.
2. **Fetches from models.dev API**: Retrieves comprehensive model metadata from [models.dev](https://models.dev), which aggregates LLM documentation across providers. It provides details about model capabilities, pricing, context windows, and more.
3. **Merges the data**: Combines provider-specific data with models.dev metadata. Provider data takes precedence for availability, while models.dev enriches models with additional details.
4. **Updates the in-memory registry**: Replaces the current registry with the refreshed data.

The method returns a chainable `Models` instance, allowing you to immediately query the updated registry:

```ruby
chat_models = RubyLLM.models.refresh!.chat_models
```

**Note:** models.dev is the upstream registry for RubyLLM metadata. If you encounter issues with model data, please report them via the models.dev site or repo.

**Local Provider Models:**

By default, `refresh!` includes models from local providers like Ollama and GPUStack if they're configured. To exclude local providers and only fetch from remote APIs:

```ruby
RubyLLM.models.refresh!(remote_only: true)
```

This is useful when you want to refresh only cloud-based models without querying local model servers.

**For Gem Development:**

The `rake models:update` task is designed for gem maintainers and updates the `models.json` file shipped with the gem:

```bash
bundle exec rake models:update
```

This task is not intended for Rails applications as it writes to gem directories and requires the full gem development environment.

**Persisting Models to Your Database:**

For Rails applications, the install generator sets up everything automatically:

```bash
bin/rails generate ruby_llm:install
bin/rails db:migrate
```

This creates the Model table and loads model data from the gem's registry.

To refresh model data from provider APIs:

```ruby
# Fetches latest model info from configured providers (requires API keys)
Model.refresh!
```

## Exploring and Finding Models

Use `RubyLLM.models` to explore the registry.

### Listing and Filtering

```ruby
all_models = RubyLLM.models.all

chat_models = RubyLLM.models.chat_models
embedding_models = RubyLLM.models.embedding_models

openai_models = RubyLLM.models.by_provider(:openai) # or 'openai'

# Filter by model family (e.g., all Claude 3 Sonnet variants)
claude3_sonnet_family = RubyLLM.models.by_family('claude3_sonnet')

# Chain filters and use Enumerable methods
openai_vision_models = RubyLLM.models.by_provider(:openai)
                                   .select(&:supports_vision?)

puts "Found #{openai_vision_models.count} OpenAI vision models."
```

### Finding a Specific Model

Use `find` to get a `Model::Info` object containing details about a specific model.

```ruby
model_info = RubyLLM.models.find('{{ site.models.openai_tools }}')

if model_info
  puts "Model: #{model_info.name}"
  puts "Provider: #{model_info.provider}"
  puts "Context Window: #{model_info.context_window} tokens"
else
  puts "Model not found."
end

# Find raises ModelNotFoundError if the ID is unknown
# RubyLLM.models.find('no-such-model-exists') # => raises ModelNotFoundError
```

### Model Aliases

RubyLLM uses aliases (defined in `lib/ruby_llm/aliases.json`) for convenience, mapping common names to specific versions.

```ruby
# '{{ site.models.anthropic_current }}' might resolve to 'claude-3-5-sonnet-20241022'
chat = RubyLLM.chat(model: '{{ site.models.anthropic_current }}')
puts chat.model.id # => "claude-3-5-sonnet-20241022" (or latest version)
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

*   [Model Costs]({% link _reference/model-costs.md %}) - turn token usage into a `RubyLLM::Cost` object and aggregate costs across messages.
*   [Custom Endpoints and Unlisted Models]({% link _reference/custom-endpoints.md %}) - target OpenAI-compatible endpoints and use model IDs the registry doesn't list.
*   [Available Models]({% link _reference/available-models.md %}) - browse every model currently registered with RubyLLM.

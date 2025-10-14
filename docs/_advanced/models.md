---
layout: default
title: Model Registry
nav_order: 4
description: Access hundreds of AI models from all major providers with one simple API
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
*   How to find and filter available models based on provider, type, or capabilities.
*   How to understand model capabilities and pricing using `Model::Info`.
*   How to use model aliases for convenience.
*   How to connect to custom endpoints (like Azure OpenAI or proxies) using `openai_api_base`.
*   How to use models not listed in the default registry using `assume_model_exists`.

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
*   **`family`**: A broader classification (e.g., `gpt4o`).

This registry allows RubyLLM to validate models, route requests correctly, provide capability information, and offer convenient filtering.

You can see the full list of currently registered models in the [Available Models Guide]({% link _reference/available-models.md %}).

### Refreshing the Registry

**For Application Developers:**

The recommended way to refresh models in your application is to call `RubyLLM.models.refresh!` directly:

```ruby
# In your application code (console, background job, etc.)
RubyLLM.models.refresh!
puts "Refreshed in-memory model list."
```

This refreshes the in-memory model registry and is what you want 99% of the time. This method is safe to call from Rails applications, background jobs, or any running Ruby process.

**How refresh! Works:**

The `refresh!` method performs the following steps:

1. **Fetches from configured providers**: Queries the APIs of all configured providers (OpenAI, Anthropic, Ollama, etc.) to get their current list of available models.
2. **Fetches from Parsera API**: Retrieves comprehensive model metadata from [Parsera](https://parsera.org), a free service that aggregates LLM documentation across providers. Parsera provides detailed information about model capabilities, pricing, context windows, and more.
3. **Merges the data**: Combines provider-specific data with Parsera's metadata. Provider data takes precedence for availability, while Parsera enriches models with additional details.
4. **Updates the in-memory registry**: Replaces the current registry with the refreshed data.

The method returns a chainable `Models` instance, allowing you to immediately query the updated registry:

```ruby
# Refresh and immediately query
chat_models = RubyLLM.models.refresh!.chat_models
```

**Note:** We're grateful to [Parsera](https://parsera.org) for providing their free API service to the LLM developer community. They maintain comprehensive, up-to-date model information by scraping provider documentation, making it available to all developers in a standardized JSON format. If you encounter issues with model data, please [file issues with Parsera](https://github.com/parsera-labs/api-llm-specs/issues).

**Local Provider Models:**

By default, `refresh!` includes models from local providers like Ollama and GPUStack if they're configured. To exclude local providers and only fetch from remote APIs:

```ruby
# Only fetch from remote providers (Anthropic, OpenAI, etc.)
RubyLLM.models.refresh!(remote_only: true)
```

This is useful when you want to refresh only cloud-based models without querying local model servers.

**For Gem Development:**

The `rake models:update` task is designed for gem maintainers and updates the `models.json` file shipped with the gem:

```bash
# Only for gem development - requires API keys and gem directory structure
bundle exec rake models:update
```

This task is not intended for Rails applications as it writes to gem directories and requires the full gem development environment.

**Persisting Models to Your Database:**

For Rails applications, the install generator sets up everything automatically:

```bash
rails generate ruby_llm:install
rails db:migrate
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
# Get a collection of all registered models
all_models = RubyLLM.models.all

# Filter by type
chat_models = RubyLLM.models.chat_models
embedding_models = RubyLLM.models.embedding_models

# Filter by provider
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
# Find by exact ID or alias
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

`find` prioritizes exact ID matches before falling back to aliases.

### Provider-Specific Resolution

Specify the provider if the same alias exists across multiple providers.

```ruby
# Get Claude 3.5 Sonnet from Anthropic
model_anthropic = RubyLLM.models.find('{{ site.models.anthropic_current }}', :anthropic)

# Get Claude 3.5 Sonnet via AWS Bedrock
model_bedrock = RubyLLM.models.find('{{ site.models.anthropic_current }}', :bedrock)
```

## Connecting to Custom Endpoints & Using Unlisted Models
{: .d-inline-block }

Sometimes you need to interact with models or endpoints not covered by the standard registry, such as:

*   Azure OpenAI Service endpoints.
*   API Proxies & Gateways (LiteLLM, Fastly AI Accelerator).
*   Self-Hosted/Local Models (LM Studio, Ollama via OpenAI adapter).
*   Brand-new model releases.
*   Custom fine-tunes or deployments with unique names.

RubyLLM offers two mechanisms for these cases:

### Custom OpenAI API Base URL (`openai_api_base`)

If you need to target an endpoint that uses the **OpenAI API format** but has a different URL, configure `openai_api_base` in `RubyLLM.configure`.

```ruby
# config/initializers/ruby_llm.rb
RubyLLM.configure do |config|
  config.openai_api_key = ENV['AZURE_OPENAI_KEY'] # Key for your endpoint
  config.openai_api_base = "https://YOUR_AZURE_RESOURCE.openai.azure.com" # Your endpoint
end
```

*   This setting **only** affects requests made with `provider: :openai`.
*   It directs those requests to your specified URL instead of `https://api.openai.com/v1`.
*   See [Configuration Guide]({% link _getting_started/configuration.md %}).

### Assuming Model Existence (`assume_model_exists`)

To use a model identifier not listed in RubyLLM's registry, use the `assume_model_exists: true` flag. This tells RubyLLM to bypass its validation check.

```ruby
# Example: Using a custom Azure deployment name
# Assumes openai_api_base is configured for your Azure endpoint
chat = RubyLLM.chat(
  model: 'my-company-secure-gpt4o', # Your custom deployment name
  provider: :openai,                # MUST specify provider
  assume_model_exists: true         # Bypass registry check
)
response = chat.ask("Internal knowledge query...")
puts response.content

# You can also use it in .with_model
chat.with_model(
  'gpt-5-alpha',
  provider: :openai,                # MUST specify provider
  assume_exists: true
)
```

The `assume_model_exists` flag also works with `RubyLLM.embed` and `RubyLLM.paint` for embedding and image generation models:

```ruby
# Custom embedding model
embedding = RubyLLM.embed(
  "Test text",
  model: 'my-custom-embedder',
  provider: :openai,
  assume_model_exists: true
)

# Custom image model
image = RubyLLM.paint(
  "A beautiful landscape",
  model: 'my-custom-dalle',
  provider: :openai,
  assume_model_exists: true
)
```

**Key Points when Assuming Existence:**

*   **`provider:` is Mandatory:** You must tell RubyLLM which API format to use (`ArgumentError` otherwise).
*   **No Validation:** RubyLLM won't check the registry for the model ID.
*   **Capability Assumptions:** Capability checks (like `supports_functions?`) are bypassed by assuming `true`. You are responsible for ensuring the model supports the features you use.
*   **Your Responsibility:** Ensure the model ID is correct for the target endpoint.
*   **Warning Log:** A warning is logged indicating validation was skipped.

Use these features when the standard registry doesn't cover your specific model or endpoint needs. For standard models, rely on the registry for validation and capability awareness. See the [Chat Guide]({% link _core_features/chat.md %}) for more on using the `chat` object.

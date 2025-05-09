---
layout: default
title: Working with Models
parent: Guides
nav_order: 9
permalink: /guides/models
---

# Working with AI Models
{: .no_toc }

RubyLLM provides a unified interface to a wide array of AI models from different providers like Anthropic, AWS Bedrock Anthropic, DeepSeek, Ollama, OpenAI, Gemini, and OpenRouter. This guide covers how RubyLLM discovers, manages, and allows you to interact with these models, including advanced scenarios like custom endpoints.
{: .fs-6 .fw-300 }

## Table of contents
{: .no_toc .text-delta }

1. TOC
{:toc}

---

After reading this guide, you will know:

*   How RubyLLM discovers and registers models.
*   How to find and filter available models based on provider, type, or capabilities.
*   How to understand model capabilities and pricing using `ModelInfo`.
*   How to use model aliases for convenience.
*   How to connect to custom endpoints (like Azure OpenAI or proxies) using `openai_api_base`.
*   How to use models not listed in the default registry using `assume_model_exists`.

## The Model Registry

RubyLLM maintains an internal registry of known AI models, typically stored in `lib/ruby_llm/models.json` within the gem. This registry is populated by running the `rake models:update` task, which queries the APIs of configured providers to discover their available models and capabilities.

The registry stores crucial information about each model, including:

*   **`id`**: The unique identifier used by the provider (e.g., `gpt-4o-2024-08-06`).
*   **`provider`**: The source provider (`openai`, `anthropic`, etc.).
*   **`type`**: The model's primary function (`chat`, `embedding`, etc.).
*   **`display_name`**: A human-friendly name.
*   **`context_window`**: Max input tokens (e.g., `128_000`).
*   **`max_tokens`**: Max output tokens (e.g., `16_384`).
*   **`supports_vision`**: If it can process images.
*   **`supports_functions`**: If it can use [Tools]({% link guides/tools.md %}).
*   **`input_price_per_million`**: Cost in USD per 1 million input tokens.
*   **`output_price_per_million`**: Cost in USD per 1 million output tokens.
*   **`family`**: A broader classification (e.g., `gpt4o`).

This registry allows RubyLLM to validate models, route requests correctly, provide capability information, and offer convenient filtering.

You can see the full list of currently registered models in the [Available Models Guide]({% link guides/available-models.md %}).

### Refreshing the Registry

The `rake models:update` task updates the `models.json` file based on the currently available models from providers for which you have configured API keys.

```bash
# Ensure API keys are configured (e.g., via ENV vars)
bundle exec rake models:update
```

Additionally, you can refresh the *in-memory* model list within a running application using `RubyLLM.models.refresh!`. This is useful for long-running processes that might need to pick up newly available models without restarting. Note that this does *not* update the `models.json` file itself, only the currently loaded list.

```ruby
# In your application code (e.g., a background job scheduler)
RubyLLM.models.refresh!
puts "Refreshed in-memory model list."
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

Use `find` to get a `ModelInfo` object containing details about a specific model.

```ruby
# Find by exact ID or alias
model_info = RubyLLM.models.find('gpt-4o')

if model_info
  puts "Model: #{model_info.display_name}"
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
# 'claude-3-5-sonnet' might resolve to 'claude-3-5-sonnet-20241022'
chat = RubyLLM.chat(model: 'claude-3-5-sonnet')
puts chat.model.id # => "claude-3-5-sonnet-20241022" (or latest version)
```

`find` prioritizes exact ID matches before falling back to aliases.

### Provider-Specific Resolution

Specify the provider if the same alias exists across multiple providers.

```ruby
# Get Claude 3.5 Sonnet from Anthropic
model_anthropic = RubyLLM.models.find('claude-3-5-sonnet', :anthropic)

# Get Claude 3.5 Sonnet via AWS Bedrock
model_bedrock = RubyLLM.models.find('claude-3-5-sonnet', :bedrock)
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
*   See [Installation Guide]({% link installation.md %}#configuration).

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
  model: 'gpt-5-alpha',
  provider: :openai,                # MUST specify provider
  assume_exists: true
)
```

**Key Points when Assuming Existence:**

*   **`provider:` is Mandatory:** You must tell RubyLLM which API format to use (`ArgumentError` otherwise).
*   **No Validation:** RubyLLM won't check the registry for the model ID.
*   **Capability Assumptions:** Capability checks (like `supports_functions?`) are bypassed by assuming `true`. You are responsible for ensuring the model supports the features you use.
*   **Your Responsibility:** Ensure the model ID is correct for the target endpoint.
*   **Warning Log:** A warning is logged indicating validation was skipped.

Use these features when the standard registry doesn't cover your specific model or endpoint needs. For standard models, rely on the registry for validation and capability awareness. See the [Chat Guide]({% link guides/chat.md %}) for more on using the `chat` object.
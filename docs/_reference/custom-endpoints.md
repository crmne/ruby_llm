---
layout: default
title: Custom Endpoints and Unlisted Models
parent: "Working with Models"
nav_order: 3
description: Target OpenAI-compatible endpoints and use model IDs the registry doesn't list
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

*   When you need to step outside the standard model registry.
*   How to point `provider: :openai` requests at a custom URL with `openai_api_base`.
*   How to use model IDs the registry doesn't list with `assume_model_exists`.
*   What capability checks RubyLLM skips when you assume a model exists.
*   What you stay responsible for when bypassing registry validation.

## Connecting to Custom Endpoints & Using Unlisted Models
{: .d-inline-block }

Sometimes you need to interact with models or endpoints not covered by the standard registry, such as:

*   Azure OpenAI Service endpoints.
*   API Proxies & Gateways (LiteLLM, Fastly AI Accelerator).
*   Self-Hosted/Local Models (LM Studio, Ollama via OpenAI adapter).
*   Brand-new model releases.
*   Custom fine-tunes or deployments with unique names.

RubyLLM offers two mechanisms for these cases.

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
*   See the [Provider Setup and Custom Endpoints Guide]({% link _getting_started/configuration-providers.md %}) for the full `api_base` setup details.

### Assuming Model Existence (`assume_model_exists`)

To use a model identifier not listed in RubyLLM's registry, use the `assume_model_exists: true` flag. This tells RubyLLM to bypass its validation check.

```ruby
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
embedding = RubyLLM.embed(
  "Test text",
  model: 'my-custom-embedder',
  provider: :openai,
  assume_model_exists: true
)

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

Use these features when the standard registry doesn't cover your specific model or endpoint needs. For standard models, rely on the registry for validation and capability awareness.

## Next Steps

*   [Chat]({% link _core_features/chat.md %}) - start a conversation once your custom endpoint or unlisted model is wired up.
*   [Model Resolution]({% link _reference/model-resolution.md %}) - the exact procedure behind `assume_model_exists` and provider selection.
*   [Working with Models]({% link _reference/models.md %}) - return to the registry for validated, capability-aware models.

---
layout: default
title: Model Resolution
parent: "Working with Models"
nav_order: 1
description: How RubyLLM turns a model name into a concrete model and provider, step by step, covering aliases, the registry, provider preference, and unlisted models.
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

* The exact steps RubyLLM follows to turn a model name into a model and a provider.
* How aliases map a friendly name to a provider's versioned ID.
* How RubyLLM picks a provider when you don't name one.
* How provider-specific resolution works, including Bedrock regions and inference profiles.
* How to use a model the registry doesn't list, and what happens when resolution fails.

## Overview

Every entry point that takes a `model:` argument runs the same resolution. `RubyLLM.chat`, `RubyLLM.embed`, and `RubyLLM.paint` all hand the name to the registry, which returns two things: a `RubyLLM::Model::Info` describing the model, and the provider instance that will serve it.

```ruby
chat = RubyLLM.chat(model: "claude-sonnet-4-5")
chat.model.id        # => "claude-sonnet-4-5-20250929"  (resolved from the alias)
chat.model.provider  # => "anthropic"                   (inferred from the registry)
```

You gave a name; RubyLLM resolved it to a concrete model and chose a provider. The rest of this guide is the procedure behind that.

## The Resolution Procedure

Resolution takes a name and an optional provider, and runs in this order:

1. **Did you name a provider?** If you passed `provider:`, resolution is scoped to that provider. If not, RubyLLM searches every provider and chooses one by preference.
2. **Resolve aliases.** The name is looked up in the alias table and rewritten to the provider's versioned ID when a match exists.
3. **Look up the registry.** RubyLLM finds the model whose ID (or pre-alias name) matches in the [model registry]({% link _reference/models.md %}).
4. **Bypass the registry for unlisted models.** With `assume_model_exists: true` (or a local provider), RubyLLM skips the lookup and trusts the name you gave.
5. **Resolve the provider.** The provider comes from the matched model's `provider` field, or from the `provider:` you named.

If no model matches and you didn't ask RubyLLM to assume it exists, resolution raises `RubyLLM::ModelNotFoundError`.

## Aliases

An alias is a stable, friendly name that maps to a provider's exact, versioned model ID. Aliases live in `aliases.json` and are shaped as `friendly-name => { provider => versioned-id }`:

```json
{
  "claude-3-5-haiku": {
    "anthropic": "claude-3-5-haiku-20241022",
    "openrouter": "anthropic/claude-3.5-haiku",
    "bedrock": "anthropic.claude-3-5-haiku-20241022-v1:0",
    "vertexai": "claude-3-5-haiku"
  }
}
```

When you name a provider, RubyLLM uses that provider's entry. Without a provider, it uses the first entry listed for the alias:

```ruby
RubyLLM.chat(model: "claude-3-5-haiku")                   # resolves to anthropic's claude-3-5-haiku-20241022
RubyLLM.chat(model: "claude-3-5-haiku", provider: :bedrock) # resolves to anthropic.claude-3-5-haiku-20241022-v1:0
```

A name that isn't in the alias table is passed through unchanged, so exact model IDs always work.

## Resolving Without a Provider

When you don't name a provider, the same name can exist across several services, so RubyLLM has to choose one. It collects every registry model whose ID matches either the name you gave or its alias-resolved ID, then picks the most preferred provider.

Provider preference puts first-party providers ahead of the aggregators that resell their models:

| Rank | Providers |
| --- | --- |
| First-party | `openai`, `anthropic`, `gemini`, `deepseek`, `mistral`, `perplexity`, `xai` |
| Cloud platforms | `vertexai`, `bedrock` |
| Aggregators and local | `openrouter`, `azure`, `ollama`, `gpustack` |

Preference decides the winner even when another provider has a more literal match. `claude-3-5-haiku` is an exact ID on Vertex AI and an alias on Anthropic, but Anthropic outranks Vertex AI, so a bare `claude-3-5-haiku` resolves to Anthropic:

```ruby
RubyLLM.chat(model: "claude-3-5-haiku").model.provider  # => "anthropic"
```

To pin a different provider, name it:

```ruby
RubyLLM.chat(model: "claude-3-5-haiku", provider: :vertexai)
```

> Provider preference only breaks ties between providers that both carry the model. It never makes RubyLLM use a provider you haven't configured a key for, because a chat still needs that provider's credentials to run.
{: .note }

## Resolving With a Provider

When you pass `provider:`, RubyLLM resolves the alias for that provider, then finds the model whose ID matches the resolved ID (falling back to the raw name) for that provider only.

```ruby
RubyLLM.embed("hello", model: "text-embedding-3-small", provider: :openai)
```

### Bedrock Regions and Inference Profiles

Bedrock adds one more step. Its model IDs carry a region prefix and may require an inference profile, so before the registry lookup RubyLLM rewrites the ID for your configured `bedrock_region`:

```ruby
RubyLLM.configure { |config| config.bedrock_region = "us-east-1" }

chat = RubyLLM.chat(model: "claude-3-5-haiku", provider: :bedrock)
chat.model.id  # => "us.anthropic.claude-3-5-haiku-20241022-v1:0"  (region prefix applied)
```

RubyLLM only applies the prefix when a matching regional model exists in the registry, and normalizes the inference-profile form from the model's metadata. See [Custom Endpoints and Unlisted Models]({% link _reference/custom-endpoints.md %}) for routing the same model through a different provider.

## Models the Registry Doesn't List

New releases, custom fine-tunes, and private deployments won't be in the registry. Set `assume_model_exists: true` to skip the registry lookup and use the name as-is. You must name a provider, since there is no registry entry to infer one from:

```ruby
chat = RubyLLM.chat(
  model: "my-custom-deployment",
  provider: :openai,
  assume_model_exists: true
)
```

RubyLLM then builds a synthetic `Model::Info` with assumed capabilities (`function_calling`, `streaming`, `vision`, `structured_output`) and a metadata warning, because it can't know the real ones:

```ruby
chat.model.capabilities  # => ["function_calling", "streaming", "vision", "structured_output"]
chat.model.metadata      # => { warning: "Assuming model exists, capabilities may not be accurate" }
```

You are responsible for using only the features the model actually supports. The same flag works on `RubyLLM.embed` and `RubyLLM.paint`, and on `with_model` as `assume_exists: true`.

> Local providers like Ollama and GPUStack assume models exist automatically. You can pull and run any model name without registering it first, and you don't need to pass the flag.
{: .note }

## When Resolution Fails

If nothing matches and you didn't assume existence, RubyLLM raises `RubyLLM::ModelNotFoundError` with guidance to refresh the registry:

```ruby
RubyLLM.chat(model: "gpt-7-ultra")
# => RubyLLM::ModelNotFoundError: Unknown model: "gpt-7-ultra". If the model exists at the
#    provider, refresh the registry with `RubyLLM.models.refresh!` and persist it with
#    `RubyLLM.models.save_to_json`.
```

A real but newly released model usually means your registry is stale. Refresh it from the provider APIs:

```ruby
RubyLLM.models.refresh!
RubyLLM.models.save_to_json
```

See [Working with Models]({% link _reference/models.md %}#refreshing-the-registry) for refreshing in applications and Rails. If the model genuinely isn't in any catalog, use `assume_model_exists: true` instead.

## Next Steps

* [Working with Models]({% link _reference/models.md %}) - explore, filter, and inspect the registry.
* [Custom Endpoints and Unlisted Models]({% link _reference/custom-endpoints.md %}) - point a provider at a custom host and use unlisted models.
* [Custom Providers and Protocols]({% link _reference/custom-providers.md %}) - teach RubyLLM about a service it doesn't know.

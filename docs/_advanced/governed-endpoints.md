---
layout: default
title: Governed Endpoints
nav_order: 6
description: Route RubyLLM through OpenAI-compatible gateways for centralized policy, audit, and cost controls.
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

RubyLLM can connect to OpenAI-compatible gateways by setting `openai_api_base`. This is useful when a Rails application needs a central control plane for policy, audit trails, model routing, quotas, or cost controls while keeping the same RubyLLM API in application code.

The gateway owns model access and operating controls. RubyLLM still owns the Ruby interface for chat, tools, embeddings, streaming, and Rails integration.

## Example: Tuning Engines

Tuning Engines exposes an OpenAI-compatible endpoint for routing model calls through centralized compliance, control, and cost policies.

```ruby
RubyLLM.configure do |config|
  config.openai_api_key = ENV["TUNING_ENGINES_API_KEY"]
  config.openai_api_base = "https://api.tuningengines.com/v1"
end

chat = RubyLLM.chat(
  model: ENV.fetch("TUNING_ENGINES_MODEL", "your-model-alias"),
  provider: :openai,
  assume_model_exists: true
)

chat.ask("Summarize the production controls on this AI request.")
```

Use a model alias that is enabled in your Tuning Engines catalog. The API key should be an inference key, not a provider secret.

## Rails configuration

For Rails applications, keep the endpoint and key in credentials or environment variables:

```ruby
# config/initializers/ruby_llm.rb
RubyLLM.configure do |config|
  config.openai_api_key = Rails.application.credentials.tuning_engines_api_key || ENV["TUNING_ENGINES_API_KEY"]
  config.openai_api_base = ENV.fetch("TUNING_ENGINES_API_BASE", "https://api.tuningengines.com/v1")
end
```

Then pass your governed model alias when creating chats:

```ruby
RubyLLM.chat(
  model: "support-triage-fast",
  provider: :openai,
  assume_model_exists: true
)
```

## When to use this pattern

Use a governed endpoint when you want one or more of these controls outside individual application code paths:

*   tenant, user, or role-based model access
*   policy and guardrail decisions before inference
*   model routing, fallbacks, quotas, or budget ceilings
*   centralized traces, audit logs, and cost reporting
*   consistent model aliases across multiple Rails applications

For local servers, LiteLLM, vLLM, Ollama, and other OpenAI-compatible endpoints, use the same `openai_api_base` pattern shown in the [Configuration Guide]({% link _getting_started/configuration.md %}#openai-compatible-apis).

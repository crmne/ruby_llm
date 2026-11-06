---
layout: default
title: Configuration
nav_order: 6
has_children: true
description: Set provider credentials, choose default models, and give parts of your application their own settings.
redirect_from:
  - /configuration-reference/
---

# {{ page.title }}

{{ page.description }}
{: .fs-6 .fw-300 }

After reading this guide, you will know:

* How to configure the providers you use.
* How to set default models for chats and individual operations.
* How to configure RubyLLM in a Rails initializer.
* How to give an agent or a tenant its own credentials with a context.
* Where to find every setting.

## Configuring Providers

`RubyLLM.configure` sets your application's credentials and defaults. Configure each provider you use with its API key:

```ruby
RubyLLM.configure do |config|
  config.openai_api_key = ENV.fetch("OPENAI_API_KEY")
  config.anthropic_api_key = ENV.fetch("ANTHROPIC_API_KEY")
end
```

That's all most applications need. RubyLLM chooses default models, timeouts, and retries, and you change only what your application needs.

Configure only the providers you use. RubyLLM doesn't ask for the others, and raises `RubyLLM::ConfigurationError` when you use a provider without its required credentials. See [Provider Setup]({% link _reference/configuration-providers.md %}) for every provider's settings, including regions, projects, Bedrock and Vertex AI authentication, and OpenAI-compatible endpoints.

## Configuring RubyLLM in Rails

In Rails, the install generator writes `config/initializers/ruby_llm.rb`. Read keys from your credentials and send RubyLLM's logs to the Rails log:

```ruby
# config/initializers/ruby_llm.rb
RubyLLM.configure do |config|
  config.openai_api_key = Rails.application.credentials.openai_api_key
  config.anthropic_api_key = Rails.application.credentials.anthropic_api_key
  config.default_model = "{{ site.models.anthropic_current }}"
  config.logger = Rails.logger
end
```

See [Rails Integration]({% link _getting_started/rails.md %}) for persistence, attachments, streaming, and jobs.

## Default Models

`RubyLLM.chat` and each individual operation use a default model when you don't pass `model:`. Set the defaults your application needs:

```ruby
RubyLLM.configure do |config|
  config.default_model = "{{ site.models.anthropic_current }}"                     # RubyLLM.chat and agents
  config.default_embedding_model = "{{ site.models.embedding_large }}"            # RubyLLM.embed
  config.default_image_model = "{{ site.models.default_image }}"                  # RubyLLM.paint
  config.default_video_model = "{{ site.models.default_video }}"                  # RubyLLM.animate
  config.default_speech_model = "{{ site.models.default_speech }}"                # RubyLLM.speak
  config.default_transcription_model = "{{ site.models.default_transcription }}"  # RubyLLM.transcribe
  config.default_ocr_model = "{{ site.models.default_ocr }}"                      # RubyLLM.ocr
  config.default_moderation_model = "{{ site.models.default_moderation }}"        # RubyLLM.moderate
  config.default_judgment_model = "{{ site.models.judgment }}"                    # RubyLLM.judge
end
```

Without them, RubyLLM uses these models:

| Setting | Default |
| --- | --- |
| `default_model` | `{{ site.models.default_chat }}` |
| `default_embedding_model` | `{{ site.models.default_embedding }}` |
| `default_image_model` | `{{ site.models.default_image }}` |
| `default_video_model` | `{{ site.models.default_video }}` |
| `default_speech_model` | `{{ site.models.default_speech }}` |
| `default_transcription_model` | `{{ site.models.default_transcription }}` |
| `default_ocr_model` | `{{ site.models.default_ocr }}` |
| `default_moderation_model` | `{{ site.models.default_moderation }}` |
| `default_judgment_model` | `{{ site.models.judgment }}` |

`rerank` has no default: pass `model:` on each call.

## Giving Part of Your Application Its Own Settings

Global configuration suits most of an application. Sometimes one part needs different settings: the support desk bills its model usage to a separate OpenAI project, or each store on your platform brings its own key. A context is a copy of the configuration with your changes, and it has the same entry points as `RubyLLM`:

```ruby
store_ai = RubyLLM.context do |config|
  config.openai_api_key = store.openai_api_key
  config.request_timeout = 180
end

store_ai.chat.ask "Do you ship to Canada?"
store_ai.transcribe "voicemail.mp3"
```

An agent takes a context with the `context` macro, so every chat it builds uses it:

```ruby
class SupportAgent < RubyLLM::Agent
  context do |config|
    config.openai_api_key = Rails.application.credentials.support_openai_api_key
  end
end
```

See [Contexts]({% link _reference/configuration-connection.md %}#contexts-isolated-configurations) for multi-tenant applications and how contexts share connections.

## Every Setting

The reference pages list every setting:

* [Provider Setup and Custom Endpoints]({% link _reference/configuration-providers.md %}): each provider's keys, endpoints, regions, and authentication.
* [Connection, Logging and Contexts]({% link _reference/configuration-connection.md %}): timeouts, retries, proxies, logging, the model registry file, and [every other setting]({% link _reference/configuration-connection.md %}#all-other-settings) in one block.
* The [Configuration API reference]({{ '/api/RubyLLM/Configuration.html' | relative_url }}) documents each setting's type and default.

## Next Steps

* [Rails Integration]({% link _getting_started/rails.md %}): the support desk on your own records and jobs.
* [Provider Setup and Custom Endpoints]({% link _reference/configuration-providers.md %}): every provider's settings.
* [Model Registry]({% link _reference/models.md %}): find models and refresh the registry.

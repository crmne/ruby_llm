---
layout: default
title: Instrumentation
nav_order: 5
description: Observe RubyLLM requests, chats, tool calls, embeddings, and model refreshes
redirect_from:
  - /guides/instrumentation
---

# {{ page.title }}
{: .no_toc .d-inline-block }

v1.16.0+
{: .label .label-green }

{{ page.description }}.
{: .fs-6 .fw-300 }

## Table of contents
{: .no_toc .text-delta }

1. TOC
{:toc}

---

After reading this guide, you will know:

*   How to subscribe to RubyLLM events in Rails.
*   How to connect RubyLLM instrumentation outside Rails.
*   Which events RubyLLM emits.
*   Which payload fields may contain sensitive application data.

## Rails

Rails apps automatically emit RubyLLM events through `ActiveSupport::Notifications`. Subscribe to them the same way you would subscribe to Rails framework events:

```ruby
# config/initializers/ruby_llm_instrumentation.rb
ActiveSupport::Notifications.subscribe('chat.ruby_llm') do |_name, _start, _finish, _id, payload|
  Rails.logger.info(
    provider: payload[:provider],
    model: payload[:model],
    input_tokens: payload[:input_tokens],
    output_tokens: payload[:output_tokens]
  )
end
```

When an instrumented block raises, Rails adds the standard `:exception` and `:exception_object` payload keys.

## Outside Rails

Outside Rails, set `config.instrumenter` to any object that responds to `instrument(name, payload) { ... }`:

```ruby
class AppInstrumenter
  def instrument(name, payload)
    started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)

    result = yield if block_given?
    result
  rescue StandardError => error
    payload = payload.merge(
      exception: [error.class.name, error.message],
      exception_object: error
    )
    raise
  ensure
    duration = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at
    Observability.record(name, payload.merge(duration: duration))
  end
end

RubyLLM.configure do |config|
  config.instrumenter = AppInstrumenter.new
end
```

You can also set `instrumenter` on a [context]({% link _getting_started/configuration.md %}#contexts-isolated-configurations) when you only want instrumentation around a specific operation.

## Events

RubyLLM emits these events:

*   `request.ruby_llm` - HTTP request metadata such as provider, method, URL, and status
*   `chat.ruby_llm` - chat completion metadata including model, provider, messages, response, and token usage
*   `tool_call.ruby_llm` - tool name, arguments, and result
*   `embedding.ruby_llm` - embedding model, input, result, token usage, and vector dimensions
*   `image.ruby_llm` - image generation model, prompt, size, and result
*   `moderation.ruby_llm` - moderation model, input, result, and flagged status
*   `transcription.ruby_llm` - transcription model, language, result, and token usage
*   `models.refresh.ruby_llm` - model registry refresh metadata

## Payloads

Payloads include the Ruby objects needed by observability adapters, but message content, tool arguments, and provider responses may be sensitive. Only export or log those fields when your application policy allows it.

Non-Rails instrumenters control their own error payload behavior. If your instrumenter records exceptions, keep those payloads consistent with the rest of your observability stack.

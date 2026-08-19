---
layout: default
title: Instrumentation and Observability
nav_order: 6
description: Observe RubyLLM model operations, provider attempts, tool calls, workflows, batches, and model refreshes
redirect_from:
  - /guides/instrumentation
---

# {{ page.title }}

{{ page.description }}
{: .fs-6 .fw-300 }

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
    input_tokens: payload[:tokens].input,
    output_tokens: payload[:tokens].output
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

You can also set `instrumenter` on a [context]({% link _getting_started/configuration-connection.md %}#contexts-isolated-configurations) when you only want instrumentation around a specific operation.

## Workflows and Steps

Use `RubyLLM.workflow` to correlate all the RubyLLM activity produced by ordinary Ruby orchestration. It does not execute, route, retry, or persist the workflow; your Ruby code remains in charge:

```ruby
RubyLLM.workflow("Write article", id: "article-42") do |workflow|
  notes = workflow.step("Research") do
    ResearchAgent.new.ask("Research Ruby 3.3 features").content
  end

  workflow.step("Draft") do
    WriterAgent.new.ask(notes).content
  end
end
```

The ID is optional. RubyLLM generates a UUID when it is omitted. Pass an application ID when you need to correlate the same logical workflow across logs, records, or background jobs.

Pass `metadata:` to attach application data to the whole workflow:

```ruby
RubyLLM.workflow("Write article", metadata: { account_id: account.id }) do |workflow|
  # ...
end
```

Nested events receive it as `workflow_metadata`, a separate key from the per-call `metadata` payload described below, so the two never collide.

`Context#workflow` provides the same API while using that context's instrumenter:

```ruby
tenant_llm.workflow("Answer support request", id: ticket.id) do |workflow|
  workflow.step("Answer") { tenant_llm.chat.ask(ticket.question) }
end
```

Every event inside the workflow receives `workflow_id` and `workflow_name`. Events inside a step also receive `workflow_step_id` and `workflow_step_name`. Nested steps include `workflow_step_parent_id`, allowing an instrumentation adapter to render the observed execution tree.

The wrappers also emit `workflow.ruby_llm` and `workflow_step.ruby_llm` events around their blocks. Their timings and exception behavior therefore come from the configured instrumenter in exactly the same way as other RubyLLM block events.

Branches, loops, fan-out, and fan-in stay as normal Ruby. For concurrent application code, start the step inside each task so the task establishes its own context:

```ruby
RubyLLM.workflow("Review code") do |workflow|
  Async do |task|
    security = task.async do
      workflow.step("Security review") { SecurityAgent.new.ask(code) }
    end
    style = task.async do
      workflow.step("Style review") { StyleAgent.new.ask(code) }
    end

    [security.wait, style.wait]
  end.wait
end
```

RubyLLM automatically carries the current workflow and step through its own concurrent tool execution. A dashboard can reconstruct what ran from these events, but the API deliberately does not declare a static graph or represent branches that never executed.

Workflows can nest. A `RubyLLM.workflow` call inside another workflow keeps its own identity: its events carry the inner `workflow_id` and `workflow_name`, plus `workflow_parent_id` and, when the nesting happened inside a step, `workflow_parent_step_id`. The outer workflow's context is restored when the inner block returns. A service object that declares its own workflow therefore appears as a sub-tree when a larger workflow calls it, the same way nested spans appear in OpenTelemetry.

Workflow context lasts exactly as long as the block. Work that resumes elsewhere, such as polling a [batch]({% link _advanced/batches.md %}) for results in a later job, is not tagged automatically; re-enter `RubyLLM.workflow` with the persisted ID to correlate it:

```ruby
RubyLLM.workflow("Nightly summaries", id: batch_record.workflow_id) do |workflow|
  workflow.step("Collect results") { RubyLLM::Batch.find(batch_record.batch_id, provider: :anthropic).messages }
end
```

## Per-Call Metadata

One-shot APIs accept `metadata:` for application observability data:

```ruby
RubyLLM.embed(
  "A short document",
  metadata: { account_id: current_account.id, feature: "search" }
)
```

RubyLLM includes that value as `payload[:metadata]` on the emitted event. It is not sent to the provider. Use `provider_options:` for provider request fields, and `metadata:` for values your own instrumentation subscribers need.

## Events

RubyLLM emits these events:

*   `workflow.ruby_llm` - one named workflow block and its correlation ID
*   `workflow_step.ruby_llm` - one named code region within a workflow
*   `request.ruby_llm` - HTTP request metadata such as provider, method, URL, and status
*   `usage.ruby_llm` - one finished provider attempt, including retries and cancellations, with status, tokens, and cost
*   `batch.ruby_llm` - one batch submission operation
*   `chat.ruby_llm` - chat completion metadata including model, provider, messages, response, and token usage
*   `tool_call.ruby_llm` - tool name, arguments, and result
*   `embedding.ruby_llm` - embedding model, input, result, token usage, and vector dimensions
*   `image.ruby_llm` - image generation model, prompt, size, and result
*   `video.ruby_llm` - one blocking video generation, including the wait for the job and the resulting video
*   `video_job.ruby_llm` - one video job submission with model, prompt, and the provider's job id
*   `moderation.ruby_llm` - moderation model, input, result, and flagged status
*   `ocr.ruby_llm` - OCR model, options, and extracted document result
*   `rerank.ruby_llm` - reranking model, query, document count, result, token usage, and cost
*   `speech.ruby_llm` - speech generation model, input, voice, format, and audio byte size
*   `transcription.ruby_llm` - transcription model, language, result, and token usage
*   `models.refresh.ruby_llm` - model registry refresh metadata

Operations that expose normalized usage (`chat`, `embedding`, `image`, `moderation`, `rerank`, `speech`, and `transcription`) include `payload[:tokens]` and `payload[:cost]`. Both value objects are always present; their individual fields may be `nil` when the provider did not report usage or RubyLLM could not price it. Batch, OCR, and video events expose their operation-specific result and lifecycle fields instead.

### Usage Events

Subscribe to `usage.ruby_llm` for cost and usage tracking that survives transport retries and chat cancellation:

```ruby
ActiveSupport::Notifications.subscribe('usage.ruby_llm') do |event|
  payload = event.payload

  Rails.logger.info(
    operation: payload[:operation],
    provider: payload[:provider],
    model: payload[:model],
    status: payload[:status],
    input_tokens: payload[:tokens].input,
    output_tokens: payload[:tokens].output,
    cost: payload[:cost].total
  )
end
```

This event fires once for every finished physical attempt. Its payload contains `operation`, `provider`, `model`, `status`, `tokens`, and `cost`. The values use the same objects as the rest of RubyLLM; the internal usage record is not part of the public API. Both objects are always present, while individual fields are `nil` when the provider supplied no defensible figure. See [Cost and Usage Tracking]({% link _core_features/cost-and-usage-tracking.md %}) for status semantics and Rails persistence.

## Payloads

Payloads include the Ruby objects needed by observability adapters, but message content, tool arguments, and provider responses may be sensitive. Only export or log those fields when your application policy allows it.

Non-Rails instrumenters control their own error payload behavior. If your instrumenter records exceptions, keep those payloads consistent with the rest of your observability stack.

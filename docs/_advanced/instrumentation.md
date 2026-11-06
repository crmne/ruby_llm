---
layout: default
title: Instrumentation and Observability
nav_order: 16
has_children: true
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
*   How to enable optional OpenTelemetry tracing.
*   Where to find the events RubyLLM emits and their payloads.
*   Which payload fields may contain sensitive application data.

## Rails

Rails apps automatically emit RubyLLM events through `ActiveSupport::Notifications`. Subscribe to them the same way you would subscribe to Rails framework events:

```ruby
# config/initializers/ruby_llm_instrumentation.rb
ActiveSupport::Notifications.subscribe('chat.ruby_llm') do |event|
  payload = event.payload
  Rails.logger.info(
    provider: payload[:provider],
    model: payload[:model],
    duration_ms: event.duration,
    cost: payload[:cost].total
  )
end
```

When an instrumented block raises, Rails adds the standard `:exception` and `:exception_object` payload keys.

## Outside Rails

You can use the same subscribers outside Rails. Add `activesupport` to your bundle, then configure its notifications module:

```ruby
require 'active_support'
require 'active_support/notifications'

RubyLLM.configure do |config|
  config.instrumenter = ActiveSupport::Notifications
end
```

Use your application's logger in subscribers instead of `Rails.logger`.

### Custom Instrumenters

To connect another observability system, set `config.instrumenter` to an object that responds to `instrument(name, payload)` with an optional block. This example passes timing and exception details to your application's `Observability.record` method:

```ruby
class AppInstrumenter
  def instrument(name, payload)
    started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)

    yield if block_given?
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

You can also set `instrumenter` on a [context]({% link _reference/configuration-connection.md %}#contexts-isolated-configurations) when you only want instrumentation around a specific operation.

## OpenTelemetry

You can trace model calls, tool execution, and workflows with OpenTelemetry. Configure your application's SDK and exporters, then enable tracing:

```ruby
RubyLLM::OpenTelemetry.enable
```

See the [OpenTelemetry guide]({% link _advanced/opentelemetry.md %}) for setup, span coverage, context propagation, and exported data. Existing subscribers continue to receive their events and payloads.

## Workflows and Steps

Use `RubyLLM.workflow` to group events from a piece of work. Each step adds its own timing and name. The code inside can call chats, agents, or individual operations:

```ruby
RubyLLM.workflow("Summarize meeting", id: "meeting-42") do |workflow|
  transcript = workflow.step("Transcribe") do
    RubyLLM.transcribe("meeting.wav").text
  end

  workflow.step("Summarize") do
    RubyLLM.chat.with_instructions("Summarize the decisions and action items.")
      .ask(transcript).content
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

The `usage.ruby_llm` event of every provider attempt carries the same identity, and in Rails each usage row stores it, so you can total the cost of a workflow and each of its steps, including calls outside any chat:

```ruby
RubyLLM::ActiveRecord::Usage.where(workflow_id: "meeting-42").group(:workflow_step_name).sum(:total_cost)
```

See [Usage by Workflow]({% link _core_features/cost-and-usage-tracking.md %}#usage-by-workflow).

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

Child fibers and threads inherit the workflow and step active when they are created. Each child can enter its own steps without changing its siblings or parent. RubyLLM also carries this context through its concurrent tool execution. A dashboard can reconstruct the work that ran from these events. Your application controls scheduling, retries, and persistence.

Workflows can nest. A `RubyLLM.workflow` call inside another workflow keeps its own identity: its events carry the inner `workflow_id` and `workflow_name`, plus `workflow_parent_id` and, when the nesting happened inside a step, `workflow_parent_step_id`. The outer workflow's context is restored when the inner block returns. A service object that declares its own workflow therefore appears as a sub-tree when a larger workflow calls it, the same way nested spans appear in OpenTelemetry.

The caller's previous context is restored when the block returns. Children retain the context they inherit, even if they run after that block returns. Context does not propagate automatically to a background job or another process. Work that resumes elsewhere, such as polling a [batch]({% link _advanced/batches.md %}) for results in a later job, is not tagged automatically; re-enter `RubyLLM.workflow` with the persisted ID to correlate it:

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

RubyLLM emits one event per operation, such as `chat.ruby_llm`, `tool_call.ruby_llm`, or `embedding.ruby_llm`, plus `request.ruby_llm` for each HTTP request, counting its retries as one, and `usage.ruby_llm` for each provider attempt. [Instrumentation Events]({% link _reference/instrumentation-events.md %}) lists every event, when it fires, and the payload fields it carries.

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

The event fires once for every finished physical attempt of a tracked operation. See [Usage Events]({% link _reference/instrumentation-events.md %}#usage-events) for its payload, what `model` can hold, and how jobs and batches report differently, and [Cost and Usage Tracking]({% link _core_features/cost-and-usage-tracking.md %}) for status semantics and Rails persistence.

## Payloads

Payloads include the Ruby objects needed by observability adapters, but message content, tool arguments, and provider responses may be sensitive. Only export or log those fields when your application policy allows it.

Non-Rails instrumenters control their own error payload behavior. If your instrumenter records exceptions, keep those payloads consistent with the rest of your observability stack.

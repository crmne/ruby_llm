---
layout: default
title: Instrumentation Events
nav_order: 3
description: Every event RubyLLM emits, when it fires, and the payload fields your subscribers can read.
---

# {{ page.title }}

{{ page.description }}
{: .fs-6 .fw-300 }

Subscribe to these events as shown in [Instrumentation and Observability]({% link _advanced/instrumentation.md %}).

## Events

| Event | When | Key fields |
| --- | --- | --- |
| `workflow.ruby_llm` | Around one named `RubyLLM.workflow` block | `workflow_id`, `workflow_name` |
| `workflow_step.ruby_llm` | Around one named code region within a workflow | `workflow_step_id`, `workflow_step_name` |
| `evaluation.ruby_llm` | Around one evaluation run | `evaluation_id`, `evaluation_name`, `total`, `completed`, `started_at`, `report` |
| `evaluation_trial.ruby_llm` | Around one evaluation case and repetition | `evaluation_id`, `evaluation_name`, `total`, `case`, `repetition`, `completed`, `trial` |
| `request.ruby_llm` | Around one request through a provider's connection, including its retries | `provider`, `method`, `url`, and `status` unless the request raises |
| `usage.ruby_llm` | After every finished attempt of a tracked operation, including retries and cancellations | `operation`, `provider`, `model`, `status`, `tokens`, `cost`, `owner`, and the workflow fields |
| `batch.ruby_llm` | Around one batch submission | `provider`, `provider_class`, `requests`, and `batch_id` after submission |
| `agent.ruby_llm` | Around one run of a chat an agent configured | `agent_name`, `agent_description`, `chat`, `chat_id` |
| `chat.ruby_llm` | Around one chat completion | `chat`, `provider`, `provider_class`, `model`, `model_info`, `input_messages`, `messages_after`, `response`, `streaming`, `tokens`, `cost`, `response_tokens`, `agent_name` |
| `tool_call.ruby_llm` | Around one tool execution | `tool_name`, `tool_arguments`, `tool_call_id`, `result`, `agent_name` |
| `mcp_unreachable.ruby_llm` | When a chat can't list an MCP server's tools and goes on without them, at most once a minute per server | `server`, `error` |
| `code_execution.ruby_llm` | Around one [code execution]({% link _advanced/code-execution.md %}) run | `tool_name`, `tool_call_id`, `language`, `sandbox`, `timeout`, `network`, `duration`, `exit_code`, `timed_out`, `blocked_hosts`, `files` |
| `embedding.ruby_llm` | Around one embedding request | `input`, `dimensions`, `embedding_dimensions`, `embedding_count`, `tokens`, `cost` |
| `image.ruby_llm` | Around one image generation | `prompt`, `size`, `count`, `tokens`, `cost` |
| `video.ruby_llm` | Around one blocking video generation, including the wait for the job | `model`, `prompt`, `job_id`, `result`, `response_model`, `provider_options`, `metadata` |
| `video_job.ruby_llm` | Around one video job submission | `prompt`, `job_id` |
| `research_job.ruby_llm` | Around one hosted research job submission | `provider`, `agent`, `prompt`, `job_id`, `status` |
| `moderation.ruby_llm` | Around one moderation request | `input`, `attachment_count`, `flagged`, `tokens`, `cost` |
| `ocr.ruby_llm` | Around one OCR request | `pages` |
| `rerank.ruby_llm` | Around one reranking request | `query`, `document_count`, `top_n`, `tokens`, `cost` |
| `judgment.ruby_llm` | Around one judgment | `question_count`, `attachment_count`, `tokens`, `cost` |
| `speech.ruby_llm` | Around one speech generation | `input`, `voice`, `format`, `streaming`, `audio_bytes`, `tokens`, `cost` |
| `transcription.ruby_llm` | Around one transcription | `language`, `temperature`, `streaming`, `tokens`, `cost` |
| `tokenization.ruby_llm` | Around one tokenization | `model`, `provider`, `result` |
| `compaction.ruby_llm` | Around one provider-side compaction of a chat's history | The same fields as `chat.ruby_llm`, except `response_tokens` |
| `models.refresh.ruby_llm` | Around one model registry refresh | `remote_only`, `model_count`, `failed_providers` |

The `embedding`, `image`, `judgment`, `moderation`, `ocr`, `rerank`, `speech`, `transcription`, and `video_job` events also carry `provider`, `provider_class`, `model`, `model_info`, `provider_options`, and `metadata`. All of them except `video_job` add `result` and `response_model` when the call succeeds.

See [Progress and Monitoring]({% link _advanced/evaluations.md %}#progress-and-monitoring) in the Evaluations guide for evaluation progress, run IDs, and report payloads.

## Agent Events

`agent.ruby_llm` wraps one run of a chat an [agent]({% link _getting_started/agents.md %}) configured: a turn of `ask` or `complete`, or a single `step`, `generate`, or `run_tools`. It fires however you reach the chat: through the agent, the chat that `Agent.chat` returns, or a Rails chat record from `create`, `create!`, or `find`, including its `to_llm` chat. The model calls and tool executions of the run happen inside it, so their events come first.

A run opens one event, however many moves it takes. A turn that goes on to answer a steering message queued while it ran stays in the same event, and two `ask` calls on the same chat give two events. A subagent that runs inside a tool opens its own event, nested in its parent's.

| Field | Contents |
| --- | --- |
| `agent_name` | The agent's class name, or `nil` for an anonymous agent class |
| `agent_description` | The agent's `description`, present only when it has one |
| `chat` | The `RubyLLM::Chat` that runs, the same object as in `chat.ruby_llm` |
| `chat_id` | The ID of the Rails chat record, present only for a persisted chat |

The workflow fields are added as usual. `chat.ruby_llm`, `compaction.ruby_llm`, and `tool_call.ruby_llm` also carry `agent_name` when the chat belongs to a named agent class, so subscribers can attribute model calls and tools without tracking the enclosing event.

## Tokens and Cost

Operations that expose normalized usage (`chat`, `embedding`, `image`, `judgment`, `moderation`, `rerank`, `speech`, and `transcription`) include `payload[:tokens]` and `payload[:cost]`. Both value objects are always present. Their individual fields are `nil` when the provider did not report usage or RubyLLM could not price it. Batch, OCR, and video events expose their operation-specific fields instead.

`chat.ruby_llm` also includes `response_tokens`, the usage for that model call before earlier fallback attempts are attached to the returned message. On failure it contains any usage recorded for that call. The `tokens` field keeps its response-level meaning.

## Usage Events

`usage.ruby_llm` fires once for every finished physical attempt of a tracked operation. Tokenization is not tracked and emits no usage event. Jobs and batches report differently, so don't treat the event count as a request count:

*   A video or research job reports when a job object first sees it finished, so another object that loads the finished job reports it again.
*   A batch reports when its results are collected, under the workflow active then: one event per successful result, and one for a failed slot only when the provider billed it. A batch picked up with `Batch.find` without its chats or requests reports once per `Batch` object, so collecting it in two places reports it twice.

The payload contains `operation`, `provider`, `model`, `status`, `tokens`, and `cost`. The values use the same objects as the rest of RubyLLM; the internal usage record is not part of the public API. Both `tokens` and `cost` are always present. Their individual fields are `nil` when an attempt may have been billed and the provider supplied no defensible figure. When an operation has a resolved model, an attempt that cannot have been billed, such as one that never reached the provider, reports zero input and output tokens. Without a resolved model, those fields stay `nil`. `cost` uses the provider's reported amount when there is one. Otherwise token-priced operations calculate it from the tokens and registry pricing, and a hosted research job, billed per task, leaves it unknown.

`model` is `nil` for operations that do not select a model, so subscribers should accept a missing model. It can also hold the provider's own resource identifier rather than a registry model ID: the hosted agent's ID for a research job, or the guardrail's `id:version` for Bedrock moderation. See [Cost and Usage Tracking]({% link _core_features/cost-and-usage-tracking.md %}) for status semantics and Rails persistence.

## Workflow Fields

Every event inside a [workflow]({% link _advanced/instrumentation.md %}#workflows-and-steps) carries these fields when they apply. A `usage.ruby_llm` event reports the workflow its attempt started in, even when it finishes outside that block, such as a polled video job. An attempt that started outside any workflow reports the workflow it finishes in, if any. To attribute a batch collected later to its original workflow, [re-enter that workflow]({% link _advanced/instrumentation.md %}#workflows-and-steps) when you collect it.

| Field | Present |
| --- | --- |
| `workflow_id`, `workflow_name` | Inside any workflow |
| `workflow_metadata` | When the workflow was given `metadata:` |
| `workflow_step_id`, `workflow_step_name` | Inside a step |
| `workflow_step_parent_id` | Inside a nested step |
| `workflow_parent_id` | Inside a workflow nested in another workflow |
| `workflow_parent_step_id` | Inside a workflow nested within a step of another workflow |

## Other Fields

| Field | Present |
| --- | --- |
| `metadata` | When a one-shot API was called with `metadata:` |
| `exception`, `exception_object` | When an instrumented block raises and the instrumenter is `ActiveSupport::Notifications` |

Non-Rails instrumenters control their own error payload behavior.

## Context Across Concurrent Tools

When a chat runs [tools concurrently]({% link _tools/tool-execution.md %}#concurrent-tool-execution), each tool call runs in its own thread or fiber. An instrumenter that keeps its current span in thread or fiber state would lose it there, so a `tool_call.ruby_llm` event would start without its parent.

An instrumenter can carry that state across by also responding to two optional methods:

*   `capture_context` returns whatever identifies the current span. RubyLLM calls it in the chat's thread before it starts the tools.
*   `with_context(value) { ... }` makes that value current for the block. RubyLLM wraps each tool call with it, in both `:threads` and `:fibers` mode.

RubyLLM uses the instrumenter of the chat's own configuration, so this works for a [context]({% link _reference/configuration-connection.md %}#contexts-isolated-configurations) with its own instrumenter too. An instrumenter that wraps another one passes both methods through, keeping the inner one's context:

```ruby
class TracingInstrumenter
  def initialize(inner)
    @inner = inner
  end

  def instrument(name, payload, &block)
    Tracing.span(name) do
      @inner.respond_to?(:instrument) ? @inner.instrument(name, payload, &block) : block&.call
    end
  end

  def capture_context
    [Tracing.current_span, @inner.respond_to?(:capture_context) && @inner.capture_context]
  end

  def with_context((span, inner))
    Tracing.with_span(span) do
      @inner.respond_to?(:with_context) ? @inner.with_context(inner) { yield } : yield
    end
  end
end

RubyLLM.configure do |config|
  config.instrumenter = TracingInstrumenter.new(config.instrumenter)
end
```

Both methods are optional. Without them, events from concurrent tools still arrive, with no parent from your instrumenter.

## Next Steps

* [Instrumentation]({% link _advanced/instrumentation.md %}): subscribe to these events.
* [OpenTelemetry]({% link _advanced/opentelemetry.md %}): send them to your tracing backend.

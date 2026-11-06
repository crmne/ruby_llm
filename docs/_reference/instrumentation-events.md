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
| `evaluation.ruby_llm` | Around one evaluation run | Progress counts and the completed report |
| `evaluation_trial.ruby_llm` | After one evaluation case and repetition completes | The trial result |
| `request.ruby_llm` | Around one HTTP request to a provider, including its retries | `provider`, `method`, `url`, `status` |
| `usage.ruby_llm` | After every finished provider attempt, including retries and cancellations | `operation`, `provider`, `model`, `status`, `tokens`, `cost`, `owner`, and the workflow fields |
| `batch.ruby_llm` | Around one batch submission | `provider`, `provider_class`, `requests`, and `batch_id` after submission |
| `chat.ruby_llm` | Around one chat completion | Model, provider, messages, response, `tokens`, `cost`, `response_tokens` |
| `tool_call.ruby_llm` | Around one tool execution | `tool_name`, `tool_arguments`, `tool_call_id`, `result` |
| `code_execution.ruby_llm` | Around one [code execution]({% link _advanced/code-execution.md %}) run | Language, duration, exit code, timeout, blocked hosts, returned files |
| `embedding.ruby_llm` | Around one embedding request | Model, input, result, `tokens`, `cost`, vector dimensions |
| `image.ruby_llm` | Around one image generation | Model, prompt, size, result, `tokens`, `cost` |
| `video.ruby_llm` | Around one blocking video generation, including the wait for the job | Model, prompt, the resulting video |
| `video_job.ruby_llm` | Around one video job submission | Model, prompt, the provider's job ID |
| `research_job.ruby_llm` | Around one hosted research job submission | `provider`, `agent`, `prompt`, `job_id`, `status` |
| `moderation.ruby_llm` | Around one moderation request | Model, input, result, flagged status, `tokens`, `cost` |
| `ocr.ruby_llm` | Around one OCR request | Model, provider options, the extracted document |
| `rerank.ruby_llm` | Around one reranking request | Model, query, document count, result, `tokens`, `cost` |
| `judgment.ruby_llm` | Around one judgment | Model, question count, attachment count, result, `tokens`, `cost`, application metadata |
| `speech.ruby_llm` | Around one speech generation | Model, input, voice, format, audio byte size, `tokens`, `cost` |
| `transcription.ruby_llm` | Around one transcription | Model, language, result, `tokens`, `cost` |
| `tokenization.ruby_llm` | Around one tokenization | Model and result |
| `compaction.ruby_llm` | Around one provider-side compaction of a chat's history | The same fields as `chat.ruby_llm`, except `response_tokens` |
| `models.refresh.ruby_llm` | Around one model registry refresh | `remote_only`, `model_count`, `failed_providers` |

See [Progress and Monitoring]({% link _advanced/evaluations.md %}#progress-and-monitoring) in the Evaluations guide for evaluation progress, run IDs, and report payloads.

## Tokens and Cost

Operations that expose normalized usage (`chat`, `embedding`, `image`, `judgment`, `moderation`, `rerank`, `speech`, and `transcription`) include `payload[:tokens]` and `payload[:cost]`. Both value objects are always present. Their individual fields are `nil` when the provider did not report usage or RubyLLM could not price it. Batch, OCR, and video events expose their operation-specific fields instead.

`chat.ruby_llm` also includes `response_tokens`, the usage for that model call before earlier fallback attempts are attached to the returned message. On failure it contains any usage recorded for that call. The `tokens` field keeps its response-level meaning.

## Usage Events

`usage.ruby_llm` fires once for every finished physical attempt. Video and research jobs are the exception: they report when a job object first sees the job finished, so another object that loads a finished job reports it again. Don't treat the event count as a request count. The payload contains `operation`, `provider`, `model`, `status`, `tokens`, and `cost`. The values use the same objects as the rest of RubyLLM; the internal usage record is not part of the public API. Both `tokens` and `cost` are always present, while their individual fields are `nil` when the provider supplied no defensible figure.

`model` is `nil` for operations that do not select a model, so subscribers should accept a missing model. For a research job, it holds the hosted agent's ID rather than a registry model ID. See [Cost and Usage Tracking]({% link _core_features/cost-and-usage-tracking.md %}) for status semantics and Rails persistence.

## Workflow Fields

Every event inside a [workflow]({% link _advanced/instrumentation.md %}#workflows-and-steps) carries these fields when they apply:

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

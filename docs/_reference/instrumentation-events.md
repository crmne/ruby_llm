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
| `request.ruby_llm` | Around one HTTP request to a provider, including its retries | `provider`, `method`, `url`, `status` |
| `usage.ruby_llm` | After every finished attempt of a tracked operation, including retries and cancellations | `operation`, `provider`, `model`, `status`, `tokens`, `cost`, `owner`, and the workflow fields |
| `batch.ruby_llm` | Around one batch submission | `provider`, `provider_class`, `requests`, and `batch_id` after submission |
| `chat.ruby_llm` | Around one chat completion | `chat`, `provider`, `provider_class`, `model`, `model_info`, `input_messages`, `messages_after`, `response`, `streaming`, `tokens`, `cost`, `response_tokens` |
| `tool_call.ruby_llm` | Around one tool execution | `tool_name`, `tool_arguments`, `tool_call_id`, `result` |
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

## Tokens and Cost

Operations that expose normalized usage (`chat`, `embedding`, `image`, `judgment`, `moderation`, `rerank`, `speech`, and `transcription`) include `payload[:tokens]` and `payload[:cost]`. Both value objects are always present. Their individual fields are `nil` when the provider did not report usage or RubyLLM could not price it. Batch, OCR, and video events expose their operation-specific fields instead.

`chat.ruby_llm` also includes `response_tokens`, the usage for that model call before earlier fallback attempts are attached to the returned message. On failure it contains any usage recorded for that call. The `tokens` field keeps its response-level meaning.

## Usage Events

`usage.ruby_llm` fires once for every finished physical attempt of a tracked operation. Tokenization is not tracked and emits no usage event. Jobs and batches report differently, so don't treat the event count as a request count:

*   A video or research job reports when a job object first sees it finished, so another object that loads the finished job reports it again.
*   A batch reports when its results are collected: one event per successful result, and one for a failed slot only when the provider billed it. A batch picked up with `Batch.find` without its chats or requests reports once per `Batch` object, so collecting it in two places reports it twice.

The payload contains `operation`, `provider`, `model`, `status`, `tokens`, and `cost`. The values use the same objects as the rest of RubyLLM; the internal usage record is not part of the public API. Both `tokens` and `cost` are always present. Their individual fields are `nil` when an attempt may have been billed and the provider supplied no defensible figure. An attempt that cannot have been billed, such as one that never reached the provider, reports zero input and output tokens. `cost` uses the provider's reported amount when there is one, and otherwise calculates it from the tokens and registry pricing.

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

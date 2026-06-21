---
layout: default
title: Batches
nav_order: 10
description: Answer thousands of chats at half price with provider-side batch processing
---

# {{ page.title }}
{: .d-inline-block .no_toc }

New in 2.0
{: .label .label-green }

{{ page.description }}
{: .fs-6 .fw-300 }

## Table of contents
{: .no_toc .text-delta }

1. TOC
{:toc}

---

After reading this guide, you will know:

* How to stage questions with `ask_later`
* How to submit chats as a batch with `RubyLLM.batch`
* How to check on a batch and collect its messages, from any process
* How to handle tool calls in batched conversations
* How to persist batch results with ActiveRecord

## What are Batches?

Providers process batched requests asynchronously on their own hardware schedule (usually within an hour; processing ends within 24, and anything still unfinished comes back expired) and charge half price for the privilege. Batches are the right tool whenever nobody is waiting on the answer: nightly classification runs, bulk summarization, evaluations, backfills.

A batch in RubyLLM is an array of chats, each ending on an unanswered question. Everything in the request (model, instructions, history, schemas, temperature, attachments) rides along, so there is nothing new to learn about building requests. The one exception is `with_headers`: batch APIs have no per-request HTTP headers, so custom headers set on a chat don't apply to batched requests.

## Staging Questions

`ask_later` is `ask` without the waiting: it adds your question to the conversation and returns the chat, leaving it awaiting a response.

```ruby
chat = RubyLLM.chat(model: "claude-haiku-4-5").with_instructions("Be terse.").ask_later("What is 2 + 2?")
chat.complete? # => false, the model still owes a response
```

## Submitting a Batch

Pass the staged chats to `RubyLLM.batch`. Submission happens immediately and returns a `RubyLLM::Batch`:

```ruby
chats = documents.map do |doc|
  RubyLLM.chat(model: "claude-haiku-4-5")
    .with_instructions("Summarize the document in one paragraph.")
    .ask_later(doc.text)
end

batch = RubyLLM.batch(chats)
batch.id     # => "msgbatch_01EhcDuvb5XfWqcdJArbsfNX"
batch.status # => "in_progress"
```

Chats in one Anthropic or xAI batch can use different models, instructions, schemas, and parameters; each request stands alone:

```ruby
chats = tickets.map do |ticket|
  RubyLLM.chat(model: ticket.urgent? ? "claude-sonnet-4-5" : "claude-haiku-4-5")
    .with_instructions("You are #{ticket.team} support.")
    .ask_later(ticket.body)
end

batch = RubyLLM.batch(chats)
```

OpenAI, Azure OpenAI, Mistral, Gemini, Vertex AI, and Bedrock batch jobs are model-scoped, so those providers require one model per batch. Split mixed-model work into one batch per model.

One provider per batch, though: submitting chats from different providers raises `ArgumentError`.

## Collecting the Answers

Persist `batch.id` and walk away. From any process, any time later, look the batch up by id:

```ruby
batch = RubyLLM.batch("msgbatch_01EhcDuvb5XfWqcdJArbsfNX", provider: :anthropic)
batch.complete? # => true
```

In a long-running process, just keep asking: `complete?` reloads from the provider until the batch ends, then caches.

```ruby
batch.complete? # => false, check back later
```

Once processing ends, `messages` returns the responses in submission order:

```ruby
batch.messages.each do |message|
  message.content       # => "The document describes..."
  message.input_tokens  # => 514
end
```

When you still hold the submitted chats, each message is also appended to its conversation, so the chats come back complete and ready to continue:

```ruby
chats.first.messages.map(&:role) # => [:system, :user, :assistant]
chats.first.ask "Shorter, please."
```

Requests can fail individually (or expire at the 24-hour deadline) without failing the batch. Failed slots are `nil` in `messages` (details go to the log), and their chats stay awaiting a response; resubmit them in a fresh batch or finish them synchronously with `complete`.

Batch results arrive as JSONL rather than individual HTTP responses, so `message.raw` on a batch message is the provider result body hash, not a Faraday response with `status` or `headers`.

You can stop a running batch with `batch.cancel`; already-processed requests still return results.

{: .note }
Token usage on batch results is billed at half the standard rates. `message.cost` doesn't know about batch pricing yet and reports standard rates.

## Tools in Batches

A batch generates one model turn. When the model asks for a tool, the round ends there (providers can't call your Ruby code) and the response comes back with `tool_call?` true. You drive the rest of the [agentic loop]({% link _core_features/chat.md %}#driving-the-loop-yourself) yourself between rounds:

* `chat.complete` runs the tools and finishes the conversation synchronously, at standard prices.
* `chat.run_tools` runs the tools and stops, leaving the chat ready for the model again, i.e. for the next batch.

Looping `run_tools` into fresh batches runs entire agentic workloads at batch prices, one model turn per round:

```ruby
chats = tickets.map { |t| support_chat(t).ask_later(t.body) }

loop do
  chats.each(&:run_tools)
  pending = chats.reject(&:complete?)
  break if pending.empty?

  batch = RubyLLM.batch(pending)
  sleep 60 until batch.complete?

  # batch.messages appends each answer to its chat; drop chats whose request
  # failed (a nil slot) so the loop can terminate.
  chats -= pending.zip(batch.messages).filter_map { |chat, message| chat unless message }
end
```

`run_tools` does nothing on chats without pending tool calls, and `reject(&:complete?)` keeps the chats heading into another round while finished conversations drop out.

For tools that need human approval before acting, don't try to pause the loop. Ask inside the tool and return the outcome as its result, so the conversation stays valid:

```ruby
def execute(id:)
  return "Approval not given; the user declined." unless approved?(id)

  Record.find(id).destroy!
  "Deleted record #{id}."
end
```

## Rails Integration

Batch results flow through the same callbacks as synchronous responses, so `acts_as_chat` persistence works unchanged. `ask_later`, `run_tools`, and `complete?` all work on your records, so staged questions and collected answers land in the database with tokens and model attached.

The one new thing a batch needs is somewhere to keep its id while the provider works. The installer generates a `Batch` model for exactly that:

```ruby
class Batch < ApplicationRecord
  acts_as_batch
end
```

It stores only the provider's batch id and the chats it's processing; the conversations themselves stay in your existing `chats` and `messages` tables. (Upgrading an app from 1.x? `bin/rails generate ruby_llm:upgrade` adds the `batches` table.)

`Batch.create!` sends the staged chats to the provider and persists the record in one step:

```ruby
chats = tickets.map do |ticket|
  Chat.create!(model: "claude-haiku-4-5").ask_later(ticket.body)
end

batch = Batch.create!(chats: chats)
BatchPollJob.perform_later(batch.id)
```

A job in another process looks the batch up, checks on it, and collects:

```ruby
class BatchPollJob < ApplicationJob
  def perform(batch_id)
    batch = Batch.find(batch_id)
    return self.class.set(wait: 10.minutes).perform_later(batch_id) unless batch.complete?

    batch.messages
  end
end
```

`batch.messages` appends each answer to its chat and persists it, so the conversations come back complete with no bookkeeping on your side. It is idempotent: an answered chat ends on an assistant message, so re-running the job (a retry, an at-least-once queue) never appends an answer twice. As it polls, `complete?` caches the provider's status onto the record, so the batches still in flight are just `Batch.where(completed: false)`. Stop a running batch with `batch.cancel`.

Tools work the same way they do for plain chats. Because the records carry the whole conversation, a poll job can `run_tools` on the collected chats and submit the ones still awaiting the model as the next batch, running an agentic workload across batches at batch prices.

## Provider Notes

* **Anthropic:** up to 100,000 requests or 256 MB per batch. Mixed models in one batch are supported. Request validation is asynchronous: a malformed request comes back as a failed result after the batch ends, not as a submission error. Results stay downloadable for 29 days.
* **OpenAI:** uses the file-backed Batch API. RubyLLM supports Responses and Chat Completions payloads, and enforces OpenAI's one-model-per-file rule. Provider files are also available through `RubyLLM.upload` and `RubyLLM.download`.
* **Azure OpenAI / Foundry:** uses the OpenAI-style file-backed batch workflow under `/openai/v1`. Your Azure deployment must be a batch-capable deployment type. Provider files are also available through `RubyLLM.upload` and `RubyLLM.download`.
* **Mistral:** uses inline batch jobs for Chat Completions. One model per batch is required. Mistral provider files are available through `RubyLLM.upload` and `RubyLLM.download`.
* **Gemini:** uses inline `generateContent` batches. One model per batch is required.
* **Vertex AI:** uses `batchPredictionJobs` with Google Cloud Storage through the same storage-backed file protocol as `RubyLLM.upload`. Configure `vertexai_batch_gcs_uri` with a `gs://bucket/prefix`; the configured credentials need permission to create batch prediction jobs and read/write that bucket. RubyLLM supports Vertex Gemini, Anthropic Claude, and MaaS chat batches; Vertex-hosted Mistral batches are not wired yet.
* **Bedrock:** uses Model Invocation Jobs with Converse payloads and S3 through the same storage-backed file protocol as `RubyLLM.upload`. Configure `bedrock_batch_s3_uri` and `bedrock_batch_role_arn`; the role must allow Bedrock to read the input prefix and write results. Bedrock batch inference does not support tools or structured output, so RubyLLM rejects those requests before submission.
* **xAI:** uses native batch containers with chat completion requests. Each request carries its own model, and results are paginated and can be collected before every request has finished. xAI provider files are available through `RubyLLM.upload` and `RubyLLM.download`.
* **Other providers:** not supported by RubyLLM batches yet. `RubyLLM.batch` raises `RubyLLM::Error` for providers without batch support.

## Next Steps

* [Chatting with AI Models]({% link _core_features/chat.md %})
* [Using Tools]({% link _core_features/tools.md %})
* [Rails Integration]({% link _advanced/rails.md %})

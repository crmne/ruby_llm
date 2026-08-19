---
layout: default
title: Batches
nav_order: 4
description: Process thousands of chats asynchronously through provider-side batch APIs
---

# {{ page.title }}

{{ page.description }}
{: .fs-6 .fw-300 }

After reading this guide, you will know:

* How to stage questions with `ask_later`
* How to submit chats as a batch with `RubyLLM.batch`
* How to check on a batch and collect its messages, from any process
* How to handle tool calls in batched conversations
* How to batch embeddings with `embed_later`
* How to persist batch results with ActiveRecord

## What Are Batches?

Providers process batched requests asynchronously on their own schedule, usually at a discount from their interactive APIs. Several supported providers price batch inference at 50% of standard rates and target a 24-hour turnaround, but pricing, deadlines, and expiration behavior are provider-specific and can change. Batches are the right tool whenever nobody is waiting on the answer: nightly classification runs, bulk summarization, evaluations, and backfills.

A batch in RubyLLM is an array of chats, each ending on an unanswered question. Everything in the request (model, instructions, history, schemas, temperature, attachments) rides along, so there is nothing new to learn about building requests. The one exception is `with_headers`: batch APIs have no per-request HTTP headers, so custom headers set on a chat don't apply to batched requests. Embeddings batch too; see [Batching Embeddings](#batching-embeddings).

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

Persist `batch.id` and walk away. From any process, any time later, look the batch up by id with `RubyLLM::Batch.find`:

```ruby
batch = RubyLLM::Batch.find("msgbatch_01EhcDuvb5XfWqcdJArbsfNX", provider: :anthropic)
batch.complete? # => true
```

`Batch.find` uses the global configuration. Pass `context:` to use an isolated [configuration context]({% link _getting_started/configuration-connection.md %}) instead:

```ruby
batch = RubyLLM::Batch.find(batch_id, provider: :anthropic, context: ctx)
```

`complete?` reads the batch's last known state without contacting the provider. In a long-running process, poll with `refresh`, which re-fetches the state from the provider and returns the batch:

```ruby
sleep 60 until batch.refresh.complete?
```

Once processing ends, `messages` returns the responses in submission order:

```ruby
batch.messages.each do |message|
  message.content       # => "The document describes..."
  message.tokens.input  # => 514
end
```

When you still hold the submitted chats, each message is also appended to its conversation, so the chats come back complete and ready to continue:

```ruby
chats.first.messages.map(&:role) # => [:system, :user, :assistant]
chats.first.ask "Shorter, please."
```

Requests can fail or expire individually without failing the whole batch. Failed slots are `nil` in `messages` (details go to the log), and their chats stay awaiting a response; resubmit them in a fresh batch or finish them synchronously with `complete`.

Batch results arrive as JSONL rather than individual HTTP responses, so `message.raw` on a batch message is the provider result body hash, not a Faraday response with `status` or `headers`.

You can stop a running batch with `batch.cancel`; already-processed requests still return results.

{: .note }
Providers apply their own batch rates. `message.cost` does not account for a batch discount yet and reports the registry's standard interactive rate, so use your provider's invoice or batch pricing when reconciling spend.

## Tools in Batches

A batch generates one model turn. When the model asks for a tool, the round ends there (providers can't call your Ruby code) and the response comes back with `tool_call?` true. You drive the rest of the [agentic loop]({% link _advanced/agentic-workflows.md %}#driving-the-loop-yourself) yourself between rounds:

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
  sleep 60 until batch.refresh.complete?

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

## Batching Embeddings

Embeddings batch too, on OpenAI. `RubyLLM.embed_later` is `RubyLLM.embed` without the waiting: it stages a text and returns a `RubyLLM::EmbeddingRequest` instead of contacting the provider. Submit an array of staged requests with `RubyLLM.batch`:

```ruby
requests = documents.map do |doc|
  RubyLLM.embed_later(doc.text, model: "text-embedding-3-small")
end

batch = RubyLLM.batch(requests)
```

`embed_later` takes `model:`, `provider:`, and `dimensions:`, with the same defaults as `embed`. Each request carries its own dimensions, but OpenAI batch jobs are model-scoped, so every request in a batch must use one embedding model.

Poll with `refresh` as usual. Once processing ends, `results` returns the embeddings in submission order and fills in each request's `result`:

```ruby
sleep 60 until batch.refresh.complete?

batch.results.first.vectors # => [0.018, -0.027, ...]

documents.zip(requests).each do |doc, request|
  doc.update!(embedding: request.result.vectors)
end
```

Failed slots are `nil` in `results`, and their requests keep a `nil` result; resubmit them in a fresh batch or embed them synchronously with `RubyLLM.embed`.

A batch takes chats or embedding requests, not both; mixing them raises `ArgumentError`. Embedding batches are OpenAI-only for now.

## Rails Integration

Batch results flow through the same callbacks as synchronous responses, so `acts_as_chat` persistence works unchanged. `ask_later`, `run_tools`, and `complete?` all work on your records, so staged questions and collected answers land in the database with their usage entries attached.

The one new thing a batch needs is somewhere to keep its id while the provider works. RubyLLM stores that state internally when all inputs are persisted chats; the conversations themselves stay in your `chats` and `messages` tables. No application `Batch` model is required. (Upgrading an app from 1.x? `bin/rails generate ruby_llm:upgrade` creates the internal table.)

`RubyLLM.batch` sends the staged chats to the provider and persists the batch state in one step:

```ruby
chats = tickets.map do |ticket|
  Chat.create!(model: "claude-haiku-4-5").ask_later(ticket.body)
end

batch = RubyLLM.batch(chats)
BatchPollJob.perform_later(batch.id)
```

A job in another process looks the batch up, checks on it, and collects:

```ruby
class BatchPollJob < ApplicationJob
  def perform(batch_id)
    batch = RubyLLM::Batch.find(batch_id)
    return self.class.set(wait: 10.minutes).perform_later(batch_id) unless batch.refresh.complete?

    batch.messages
  end
end
```

`batch.messages` appends each answer to its chat and persists it, so the conversations come back complete with no bookkeeping on your side. It is idempotent: an answered chat ends on an assistant message, so re-running the job (a retry, an at-least-once queue) never appends an answer twice. Stop a running batch with `batch.cancel`.

Tools work the same way they do for plain chats. Because the records carry the whole conversation, a poll job can `run_tools` on the collected chats and submit the ones still awaiting the model as the next batch, running an agentic workload across batches at batch prices.

## Provider Notes

* **Anthropic:** up to 100,000 requests or 256 MB per batch. Mixed models in one batch are supported. Request validation is asynchronous: a malformed request comes back as a failed result after the batch ends, not as a submission error. Results stay downloadable for 29 days.
* **OpenAI:** uses the file-backed Batch API. RubyLLM supports Responses, Chat Completions, and embeddings payloads, and enforces OpenAI's one-model-per-file rule. Provider files are also available through `RubyLLM.upload` and `RubyLLM.download`.
* **Azure OpenAI / Foundry:** uses the OpenAI-style file-backed batch workflow under `/openai/v1`. Your Azure deployment must be a batch-capable deployment type. Provider files are also available through `RubyLLM.upload` and `RubyLLM.download`.
* **Mistral:** uses inline batch jobs for Chat Completions. One model per batch is required. Mistral provider files are available through `RubyLLM.upload` and `RubyLLM.download`.
* **Gemini:** uses inline `generateContent` batches. One model per batch is required.
* **Vertex AI:** uses `batchPredictionJobs` with Google Cloud Storage through the same storage-backed file protocol as `RubyLLM.upload`. Configure `vertexai_batch_gcs_uri` with a `gs://bucket/prefix`; the configured credentials need permission to create batch prediction jobs and read/write that bucket. RubyLLM supports Vertex Gemini, Anthropic Claude, and MaaS chat batches; Vertex-hosted Mistral batches are not wired yet.
* **Bedrock:** uses Model Invocation Jobs with Converse payloads and S3 through the same storage-backed file protocol as `RubyLLM.upload`. Configure `bedrock_batch_s3_uri` and `bedrock_batch_role_arn`; the configured static keys or `bedrock_credential_provider` need permission to submit the job and write the input object, while the batch role must allow Bedrock to read the input prefix and write results. Bedrock batch inference does not support tools or structured output, so RubyLLM rejects those requests before submission.
* **xAI:** uses native batch containers with chat completion requests. Each request carries its own model, and results are paginated and can be collected before every request has finished. xAI provider files are available through `RubyLLM.upload` and `RubyLLM.download`.
* **Other providers:** not supported by RubyLLM batches yet. `RubyLLM.batch` raises `RubyLLM::Error` for providers without batch support.

## Next Steps

* [Chatting with AI Models]({% link _core_features/chat.md %})
* [Using Tools]({% link _core_features/tools.md %})
* [Rails Integration]({% link _advanced/rails.md %})

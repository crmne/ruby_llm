---
layout: default
title: Batches
nav_order: 4
description: Process chats and embeddings in batches, then collect their results when they are ready.
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
* How to persist batch results with Active Record

## What Are Batches?

Batches process requests in the background, often at lower prices than interactive calls. Use them for document summaries, evaluations, and backfills when nobody is waiting for an immediate answer. Prices and turnaround depend on the provider.

Stage chats or embedding requests, submit them together, and collect their results later. Some providers need [additional setup]({% link _getting_started/configuration-providers.md %}#batch-processing).

## Staging Questions

`ask_later` adds a question and returns the chat without contacting the provider:

```ruby
chat = RubyLLM.chat(model: "{{ site.models.anthropic_current }}").ask_later("What is 2 + 2?")
chat.complete? # => false
```

## Submitting a Batch

Pass the staged chats to `RubyLLM.batch`. Submission happens immediately and returns a `RubyLLM::Batch`:

```ruby
chats = documents.map do |doc|
  RubyLLM.chat(model: "{{ site.models.anthropic_current }}")
    .with_instructions("Summarize the document in one paragraph.")
    .ask_later(doc.text)
end

batch = RubyLLM.batch(chats)
batch.id     # Save this to collect the results later
batch.status # => :pending
```

The chats keep their instructions, history, tools, schemas, and other request settings, subject to the [provider's batch restrictions](#provider-restrictions). Custom headers set with `with_headers` do not apply to batch requests.

Use one provider per batch. Anthropic and xAI allow different models in the same batch; other integrations require one model per submission.

## Collecting the Answers

Save `batch.id`. Another process can retrieve the batch with `RubyLLM::Batch.find`:

```ruby
batch = RubyLLM::Batch.find(batch_id, provider: :anthropic)
batch.complete? # => true
```

`Batch.find` needs `provider:` when RubyLLM has not persisted the batch. Pass `context: ctx` to use an isolated [configuration context]({% link _getting_started/configuration-connection.md %}).

`complete?` reads the batch's last known state without contacting the provider. In a long-running process, poll with `refresh`, which re-fetches the state from the provider and returns the batch:

```ruby
sleep 60 until batch.refresh.complete?
```

`status` normalizes the lifecycle to `:pending`, `:succeeded`, `:failed`, or `:cancelled`. `raw_status` preserves the provider's own string. The matching `succeeded?`, `failed?`, and `cancelled?` predicates let a poller distinguish a successful completion from a failed, expired, or cancelled provider job.

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

Requests can fail or expire individually without failing the whole batch. Failed slots are `nil` in `messages` (details go to the log), and their chats stay awaiting a response; resubmit them in a fresh batch or finish them synchronously with `complete`. Read `statuses` to distinguish successful, failed, and cancelled slots without inspecting provider payloads:

```ruby
batch.messages
batch.statuses # => [:succeeded, :failed, :cancelled]
```

Use `batch.cancel` to stop unfinished work where the provider supports cancellation. Collect any completed results afterward.

## Cost and Usage

Read a batch's cost and token usage through the same objects as other RubyLLM results:

```ruby
batch.cost.total
batch.tokens.input
```

`batch.cost` returns a `RubyLLM::Cost`. Its total stays `nil` until processing ends. It uses the provider's reported total when available; otherwise it adds the collected results' costs at batch rates. Missing pricing stays `nil`.

Each result also exposes `message.cost` or `embedding.cost`. A charge reported for the whole batch is not divided among its results. Rails retains batch costs when another process retrieves the batch.

## Tools in Batches

A batch generates one model turn. If a response requests a Ruby tool, run it before submitting the next turn:

```ruby
batch.messages
chats.each(&:run_tools)

pending = chats.reject(&:complete?)
next_batch = RubyLLM.batch(pending) if pending.any?
```

Repeat this sequence for more batch turns. `run_tools` does nothing when there are no pending calls. To finish a conversation immediately, call `chat.complete`; subsequent requests use interactive prices.

For tools declared with `requires_approval`, record each decision before running tools:

```ruby
chat.approve(chat.pending_approvals.first) # Or chat.deny(...)
chat.run_tools
```

Rails saves approval decisions so another process can resume. See [Tool Approvals]({% link _core_features/tool-execution.md %}#requiring-approval) and [Agentic Workflows]({% link _advanced/agentic-workflows.md %}).

## Batching Embeddings

`RubyLLM.embed_later` stages an embedding request without contacting the provider. Submit the requests with the same batch API:

```ruby
requests = documents.map do |doc|
  RubyLLM.embed_later(doc.text, model: "{{ site.models.embedding_small }}")
end

batch = RubyLLM.batch(requests)
```

`embed_later` accepts `model:`, `provider:`, and `dimensions:`, with the same defaults as `embed`. Choose a model that supports batches and use the same model and provider throughout the submission.

Poll with `refresh` as usual. Once processing ends, `results` returns the embeddings in submission order and fills in each request's `result`:

```ruby
sleep 60 until batch.refresh.complete?

batch.results.first.vectors # => [0.018, -0.027, ...]

documents.zip(requests).each do |doc, request|
  doc.update!(embedding: request.result.vectors) if request.result
end
```

Failed slots are `nil` in `results`, and their requests keep a `nil` result; resubmit them in a fresh batch or embed them synchronously with `RubyLLM.embed`.

A batch takes chats or embedding requests, not both; mixing them raises `ArgumentError`. `embed_later` stages text inputs; media attachments use the synchronous [embedding API]({% link _core_features/embeddings.md %}#embedding-images-and-other-media).

## Rails Integration

Batch results flow through the same callbacks as synchronous responses, so `acts_as_chat` persistence works unchanged. `ask_later`, `run_tools`, and `complete?` all work on your records, so staged questions and collected answers land in the database with their usage entries attached.

When all inputs are persisted chats, RubyLLM saves the batch ID and state in its own table. Your application keeps its chats and messages; it does not need a `Batch` model. The [upgrade generator]({% link _reference/upgrading.md %}) creates the supporting table for existing apps.

`RubyLLM.batch` sends the staged chats to the provider and persists the batch state in one step:

```ruby
chats = tickets.map do |ticket|
  Chat.create!(model: "{{ site.models.anthropic_current }}").ask_later(ticket.body)
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

`batch.messages` appends and persists each answer once. Retrying the polling job does not duplicate messages.

The same tool workflow works on these records: run pending tools, then batch the next model turns.

## Provider Restrictions

The batch workflow above is shared. These differences affect which requests you can submit:

| Provider | Restriction |
|----------|-------------|
| Azure | Requires a batch-capable deployment. Azure embedding batches are not currently available through RubyLLM. |
| Bedrock | Chat batches do not support tools or structured output. Region and batch-size limits depend on the model. |
| Cohere | Chat batches do not support structured output, forced tool choice, or retrieval documents. Omit `dimensions:` for embedding batches. |
| OpenRouter | Requires a model with batch access. Batches accept text input and output, with one protocol per batch. Embedding task types and provider-routing preferences are unavailable. Cancellation is not supported. |
| Vertex AI | Text embedding batches require matching dimensions and parameters across requests. |

See [batch setup]({% link _getting_started/configuration-providers.md %}#batch-processing) for dependencies, cloud storage, and permissions. Bedrock and Vertex AI keep batch files in your configured bucket after processing or cancellation; your application controls their cleanup.

## Next Steps

* [Chatting with AI Models]({% link _core_features/chat.md %})
* [Using Tools]({% link _core_features/tools.md %})
* [Rails Integration]({% link _advanced/rails.md %})

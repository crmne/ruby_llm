---
layout: default
title: Tokens and Costs
nav_order: 10
description: Read normalized token counts and costs for every response, chat, and provider attempt, including retries and cancellations.
redirect_from:
  - /chat-tokens/
  - /model-costs/
---

# {{ page.title }}

{{ page.description }}
{: .fs-6 .fw-300 }

After reading this guide, you will know:

* How to read input, output, cache, and thinking token counts from a response.
* How to read per-turn and per-conversation costs.
* How to count a request's tokens before you send it.
* What each token bucket counts.
* How the internal usage ledger accounts for retries, fallbacks, and cancellations.
* How to price token usage yourself with `cost_for` and `Cost.aggregate`.
* How to price provider tools billed per use, such as web search.
* How costs are recorded in Rails and how to keep registry pricing fresh.
* How to attribute chat and one-shot usage to a user or account.
* How to total the usage of a workflow, including calls outside its chat.

## Reading Tokens and Costs

RubyLLM prices tokens from its model registry, so your application doesn't need a table of token prices. A model the registry has no price for reports a `nil` cost, and a [tool billed per use](#pricing-tool-use) may be a charge you add yourself. Read token counts and costs directly from the response:

```ruby
chat = RubyLLM.chat
response = chat.ask "Explain Ruby blocks."

response.tokens.input
response.tokens.output
response.cost.total

chat.cost.total
```

`response.tokens` is a `RubyLLM::Tokens`; `response.cost` is a `RubyLLM::Cost`. Both are present even when some fields are unknown. Unknown values are `nil`, so a missing price does not look like a free request.

More detailed readers use the same shape:

```ruby
response.tokens.cache_read
response.tokens.cache_write
response.tokens.thinking
response.cost.input
response.cost.output
```

`response.tokens` aggregates every transport attempt associated with the response. `chat.tokens` and `chat.cost` aggregate the chat's whole internal ledger, including failed retries and cancelled attempts (see [The Usage Ledger](#the-usage-ledger) below).

The same pair of value objects is used by one-shot results. Their fields remain `nil` when the provider does not report enough information:

```ruby
embedding = RubyLLM.embed("Ruby")
embedding.tokens.input
embedding.cost.total

transcription = RubyLLM.transcribe("meeting.wav")
transcription.tokens.input
transcription.tokens.output
transcription.cost.total
```

RubyLLM uses token usage from the provider and pricing from the model registry. If the registry is missing pricing for tokens that were used, the affected cost and `cost.total` return `nil` instead of pretending the cost was zero. These helpers cover token-priced conversation usage; see [Pricing Tool Use](#pricing-tool-use) for tools billed per use, such as web search.

A calculated `cost.total` adds up the usage the provider reported, so partial usage can leave out charges. When a provider reports a response's input tokens but no output tokens, `cost.output` is `nil` and `cost.total` leaves out the output. Totals across attempts, such as `chat.tokens.output`, sum the counts that were reported, so a number there doesn't prove every attempt reported one. To check, read each attempt's `tokens` from `usage.ruby_llm` or the usage ledger.
{: .warning }

Chat responses and one-shot results resolve model pricing within the provider you called, even when another provider uses the same model ID. A transcription on Vertex AI uses Vertex AI's prices, not the Gemini API's. If the response names a model that is unknown for that provider, RubyLLM uses the requested model. `response.model_info` returns that resolved model; `response.model` keeps the ID returned by the provider.

When the provider reports a request's price, `cost.total` uses that amount instead of a registry estimate. Component costs such as `cost.input` still use registry pricing. The same rule applies to [batch costs]({% link _advanced/batches.md %}#cost-and-usage).

[Hosted research]({% link _advanced/hosted-research.md %}) is billed per task. Its cost stays unknown when the service supplies no price, even if it reports zero tokens.

## Counting Tokens Before You Send

Use `RubyLLM.count_tokens` or `chat.count_tokens` to measure chat input before generation. See [Tokenization]({% link _core_features/tokenization.md %}#counting-a-chat-request) for examples and counting limits.

## Tokenizing Plain Text

`RubyLLM.tokenize` returns a model's token IDs for a string. See the [Tokenization guide]({% link _core_features/tokenization.md %}) to inspect text and compare token counts.

## Token Buckets

Token counts use the same meanings across providers:

| Reader | What it counts |
| --- | --- |
| `tokens.input` | Standard input, excluding cache reads and writes. |
| `tokens.output` | Billable output, including thinking when it is billed as output. |
| `tokens.cache_read` | Input served from the prompt cache. |
| `tokens.cache_write` | Input written to the prompt cache. |
| `tokens.cache_write_by_ttl` | Cache writes split by lifetime, such as `{"1h" => 2048}`, when reported. |
| `tokens.thinking` | Thinking tokens, when reported. |

To measure all input activity, add the standard input, cache reads, and cache writes. A missing count is `nil`, so check for it before calculating a total.

Thinking tokens can already be included in `tokens.output`; do not add them again. When a model has distinct thinking-token pricing, `cost.thinking` prices that bucket separately. Otherwise it is part of `cost.output`.

## The Usage Ledger

An LLM transcript is not an accounting ledger. A request can be retried before one response arrives, and a cancelled stream can consume tokens without producing a completed assistant message. Counting messages therefore undercounts real provider work.

RubyLLM records each physical provider attempt internally. This changes the implementation of token and cost helpers without adding a tracking object to the public API.

One response can require several physical attempts. If a transport request fails twice and the third attempt succeeds, the response's `tokens` and `cost` aggregate the reported usage from all three attempts.

Fallbacks work the same way. When an initial model fails and a fallback produces the message, every attempt involved in that logical generation contributes to the resulting message's aggregates.

To count cancelled and failed attempts yourself, subscribe to [`usage.ruby_llm`](#instrumentation) instead of adding up messages.

A cancelled attempt may have no message to attach to. It still contributes to `chat.tokens` and `chat.cost` when RubyLLM has enough reported usage. If an attempt may have been billed but the provider supplied no defensible usage, the token fields for that attempt and `chat.cost.total` are `nil` rather than misleading zeroes. An attempt that provably never reached the provider, such as a refused connection or a failed TLS handshake, records zero tokens instead: it cannot have been billed, so it does not blank the total. So does an attempt the provider answered with an HTTP error before streaming anything, such as a 500 that a retry then recovered from. A connection that drops after the request was sent, including one reset in the middle of a stream, may have been billed and stays `nil`.

## Pricing Usage Yourself

Once a model is in the registry, RubyLLM can turn token usage into a `RubyLLM::Cost` object so you can attach a dollar figure to any usage payload:

```ruby
model = RubyLLM.models.find("{{ site.models.default_chat }}")
response = RubyLLM.chat(model: model.id, provider: model.provider).ask "Summarize Ruby's object model."

cost = model.cost_for(response.tokens)
puts cost.input
puts cost.output
puts cost.cache_read
puts cost.cache_write
puts cost.thinking
puts cost.total
```

When a model publishes a long-context tier, `cost_for` uses those rates once the prompt exceeds the registry threshold. Prompt size is `input + cache_read + cache_write`. Below that threshold, or when the model has no long-context tier, standard rates apply. Pass a chat or a message instead of its tokens to price each provider request at the tier its own prompt reached. Rails chat and message records work the same way:

```ruby
model.cost_for(chat).total
model.cost_for(Chat.find(chat_id)).total
```

When one of the requests has unknown usage, `total` is `nil`, as `chat.cost.total` is.

`cost_for(tokens, tier: :batch)` uses the model's batch rates. When the model has no batch price for a component, that amount and `total` are `nil`; see [Batches]({% link _advanced/batches.md %}).

Most applications use the shorter helpers on messages, chats, and agents: `response.cost.total`, `chat.cost.total`, `agent.cost.total`.

To combine several cost objects yourself, use `RubyLLM::Cost.aggregate`:

```ruby
cost = RubyLLM::Cost.aggregate(messages.map(&:cost))
cost.total
```

If pricing is incomplete for tokens that were used, the affected cost and `cost.total` return `nil`.

## Characters, Audio Seconds, and Search Units

Some operations are billed in units other than tokens. Text-to-speech is billed per character sent, transcription per second of audio, and Cohere reranking per search. RubyLLM counts these units next to the tokens:

```ruby
speech = RubyLLM.speak("Welcome back.", model: "{{ site.models.speech_vertexai }}", provider: :vertexai)
speech.tokens.characters # => 13
speech.cost.characters

transcription = RubyLLM.transcribe("meeting.wav", model: "{{ site.models.transcription_openai_timestamps }}")
transcription.tokens.audio_seconds # => 42
transcription.cost.audio_seconds

rerank = RubyLLM.rerank("Ruby web frameworks", documents, model: "{{ site.models.rerank_cohere }}", provider: :cohere)
rerank.tokens.search_units # => 1
rerank.cost.search_units
```

`characters` counts every character of the text sent, including spaces and newlines. `audio_seconds` is the billed length of the audio, which may be fractional. It is recorded when the provider bills transcription by duration, so a model that reports token usage leaves it `nil`. `search_units` is the count the provider reports.

`cost` prices each unit from the model registry, in US dollars per million units, and adds it to `cost.total`. When the registry has no price for a unit that was used, that component and `cost.total` are `nil`, never zero.

Token prices in the registry come from [models.dev](https://models.dev), which has no fields for these units yet. Until it does, RubyLLM fills them from each provider's published list price, checked by date, for models whose page states one plainly, such as OpenAI's `tts-1` and `whisper-1` or Cloud Text-to-Speech's `Chirp3-HD`. Once models.dev prices a model, its prices win. A model without a listed price, such as one billed differently on each plan, keeps a `nil` cost for the unit.

## Pricing Tool Use

Providers bill some [provider tools]({% link _tools/provider-tools.md %}) per use instead of per token. A web search costs the same whether it returns two results or ten. Read how many times each tool ran from `tokens.server_tool_use`:

```ruby
response = chat.with_provider_tools(:web_search).ask "What changed in Rails this week?"
response.tokens.server_tool_use # => {"web_search_requests" => 2}
```

Web searches are `web_search_requests` on every provider that reports them. Other tools follow the same form, such as `web_fetch_requests` and `code_execution_requests`. [Code you run in your own sandbox]({% link _advanced/code-execution.md %}#measuring-runs) has an entry of its own, with `code_execution_seconds`. Tools that did not run are left out, so a response that used none returns `nil`. `chat.tokens.server_tool_use` sums the whole conversation, retries included.

Price the searches at your provider's published rate:

```ruby
PRICE_PER_SEARCH = 0.01 # US dollars, from your provider's price list

searches = response.tokens.server_tool_use.to_h.fetch("web_search_requests", 0)
search_cost = searches * PRICE_PER_SEARCH
```

Unless the provider reports the price of a request, `cost.total` prices tokens only, so add the search cost to it. OpenRouter, Perplexity, and xAI report the price with their tool charges included, and `cost.total` already uses it.

On Gemini and Vertex AI, `web_search_requests` counts the distinct queries Google Search grounding ran. Gemini 3 models bill each query, but Gemini 2.5 and older bill once per grounded prompt, so price a response from those models with any searches as one charge.

## Rails Persistence

With `acts_as_chat`, RubyLLM writes finished attempts to `ruby_llm_usages` immediately. This happens before the message callback, so cancellation cannot erase usage merely because no assistant message was saved.

```ruby
chat = Chat.find(params[:id])
message = chat.messages.last

message.tokens.input
message.cost.total
chat.tokens.input
chat.cost.total
```

RubyLLM owns and writes the ledger; your application still owns only its Chat and Message models, and reads the ledger through `RubyLLM::ActiveRecord::Usage` (see [Querying RubyLLM's Records]({% link _advanced/rails-persistence.md %}#querying-rubyllms-records)). Each usage row records the operation, provider, model, status, token buckets, cost components, and timestamps in normalized columns, with numeric token and cost columns, so ordinary SQL sums and period queries work directly against `ruby_llm_usages`. A JSON `server_tool_use` column keeps the attempt's [tool use counts](#pricing-tool-use). The `characters`, `audio_seconds`, and `search_units` columns, with their `_cost` columns, keep [units billed instead of tokens](#characters-audio-seconds-and-search-units). Costs are frozen at completion, so a later `RubyLLM.models.refresh` that changes registry pricing leaves recorded usage untouched. The 2.0 upgrade moves token counts and frozen costs from pre-2.0 message columns into the ledger and removes those columns, so old and new rows read through the same path.

### One-Shot Operations

Operations outside a chat record their attempts in the same ledger. `RubyLLM.transcribe`, `embed`, `paint`, `speak`, `moderate`, `ocr`, `rerank`, and `judge` each write a row for every attempt the provider may have billed, including failed and blocked ones. A video or research job writes one row when it finishes, with the cost the provider reported. A video's cost stays unknown when its provider reports none, and a research row names the hosted agent in its `model` column. These rows have no chat. A chat without a record, such as `RubyLLM.chat` in a service object, records its rows the same way.

Pass `owner:` to attribute an operation's usage to a record, such as the user who asked for it:

```ruby
RubyLLM.transcribe("memo.m4a", owner: current_user)
RubyLLM.embed(document.body, owner: current_user.account)
```

To attribute everything a block of code does, wrap it in `RubyLLM.with_owner`:

```ruby
class ProcessUploadJob < ApplicationJob
  def perform(upload)
    RubyLLM.with_owner(upload.user) do
      transcript = RubyLLM.transcribe(upload.file_path)
      RubyLLM.embed(transcript.text)
    end
  end
end
```

An operation's `owner:` wins over the block's owner, and a nested block restores the outer owner when it ends. Each fiber and thread keeps its own owner, and fibers and threads started inside the block inherit it. Without an owner, RubyLLM still writes the row, unattributed. An owner that is not an Active Record record, such as a user ID String, reaches the [`usage.ruby_llm` event](#instrumentation) but leaves the row unattributed.

A chat takes its own owner with `with_owner`. Every attempt it makes is attributed to it: each request, the tools it runs and the model calls they make, the file converters it triggers, and compaction, including failed or cancelled attempts that produce no message:

```ruby
chat.with_owner(current_user).ask "Summarize the latest reviews."
```

A chat's owner wins over `RubyLLM.with_owner`, which still applies to a chat without one. Agents declare it with the `owner` macro, which takes a block evaluated when the chat is built:

```ruby
class SupportAgent < RubyLLM::Agent
  inputs :account
  owner { account }
end
```

Rows of an `acts_as_chat` record keep both their chat association and the owner. The owner is not persisted with the chat, so set it again, or let the agent set it, when a background job resumes the work. In a shared conversation, set it on each turn to record who caused its attempts. The chat writes each row once. Existing rows keep their recorded owner; RubyLLM does not infer one from your chat or message models.

To query an owner's spend, declare the association on the owner's model:

```ruby
class User < ApplicationRecord
  has_many :ruby_llm_usages, as: :owner, class_name: "RubyLLM::ActiveRecord::Usage", dependent: :nullify
end

current_user.ruby_llm_usages.sum(:total_cost)
current_user.ruby_llm_usages.where(created_at: Time.current.all_month).group(:operation).sum(:total_cost)
```

### Usage by Workflow

One piece of work often makes calls outside its chat: a guardrail check, an embedding for retrieval, a reranking pass. Those rows have no chat, so `chat.cost` leaves them out. Wrap the work in a [workflow]({% link _advanced/instrumentation.md %}#workflows-and-steps) and every row records it, the chat's own rows included:

```ruby
RubyLLM.workflow("Support reply", id: "chat-#{chat.id}") do |workflow|
  articles = workflow.step("Retrieve") do
    Article.closest_to(RubyLLM.embed(question).vector).limit(5)
  end

  workflow.step("Answer") do
    chat.ask("#{question}\n\nArticles:\n#{articles.map(&:body).join("\n\n")}")
  end
end
```

Each row stores `workflow_id`, `workflow_name`, `workflow_step_id`, and `workflow_step_name`, so ordinary queries sum the work:

```ruby
usages = RubyLLM::ActiveRecord::Usage.where(workflow_id: "chat-#{chat.id}")

usages.sum(:total_cost)
usages.group(:workflow_step_name).sum(:total_cost)
usages.where(created_at: Time.current.all_month).group(:operation).sum(:input_tokens)
```

Reuse the same ID on every turn, as above, to total a conversation across requests. A video or research job records the workflow it was submitted in, even when it finishes in a later job. A row records the innermost workflow it ran in, so the rows of a [nested workflow]({% link _advanced/instrumentation.md %}#workflows-and-steps) carry the nested workflow's ID. Workflows and owners are independent: a row can have both.

Writing a row never breaks the operation that billed it. If the insert fails, RubyLLM logs a warning and returns the result. Every row names what the provider ran and billed in its `model` column: the model ID, or for an operation without one, the provider's own resource, such as the hosted agent of a research task or the ID and version of a Bedrock guardrail (`my-guardrail:1`).

## Keeping Registry Pricing Fresh

Because recorded costs are frozen at completion, stale registry pricing only affects new attempts, never usage you have already saved. To keep new costs accurate, refresh the registry on a schedule. A daily job is a good default; providers change prices infrequently.

In a Rails app with the database-backed registry, the same refresh call writes the new pricing to RubyLLM's internal model table:

```ruby
# lib/tasks/ruby_llm.rake
namespace :ruby_llm do
  desc "Refresh the model registry pricing and capabilities"
  task refresh_models: :environment do
    RubyLLM.models.refresh
  end
end
```

Run `bin/rails ruby_llm:refresh_models` from cron, or schedule the call with your background job framework (GoodJob, Sidekiq, or similar). RubyLLM does not refresh the registry on its own; you choose the cadence.

## Instrumentation

Every finished physical attempt emits `usage.ruby_llm`, whether it succeeded, failed, or was cancelled. Use it when you need per-attempt detail for billing exports, metrics, or observability. Rails apps receive it out of the box; [outside Rails, set `config.instrumenter`]({% link _advanced/instrumentation.md %}) first. [Jobs and batches report differently]({% link _reference/instrumentation-events.md %}#usage-events), so read that before you sum events for billing:

```ruby
ActiveSupport::Notifications.subscribe("usage.ruby_llm") do |event|
  payload = event.payload

  Metrics.increment("llm.attempt", tags: {
    provider: payload[:provider],
    model: payload[:model],
    status: payload[:status]
  })

  Metrics.distribution("llm.input_tokens", payload[:tokens].input) if payload[:tokens].input
  Metrics.distribution("llm.cost", payload[:cost].total) if payload[:cost].total
end
```

The payload contains `operation`, `provider`, `model`, `status`, `tokens`, `cost`, and `owner`, the record given as [`owner:` or through `RubyLLM.with_owner`](#one-shot-operations). Inside a [workflow](#usage-by-workflow), it also carries `workflow_id`, `workflow_name`, and the step's `workflow_step_id` and `workflow_step_name`, from the workflow the attempt started in. It does not expose RubyLLM's internal persistence record. Without Active Record, subscribe to this event to attribute spend yourself:

```ruby
ActiveSupport::Notifications.subscribe("usage.ruby_llm") do |event|
  owner = event.payload[:owner]
  Spend.add(owner, event.payload[:cost].total) if owner && event.payload[:cost].total
end
```

`status` is `succeeded`, `failed`, or `cancelled`. `tokens` and `cost` use the same value objects returned by responses. They are always present; individual fields are `nil` when the provider did not report enough information. A failed or cancelled attempt may contain the token counts observed before it stopped. An attempt interrupted from outside, such as a stopped Async task or a process shutdown, is recorded as `cancelled`.

Instrumentation is an observer, not the source of truth for a persisted Rails chat. RubyLLM maintains the internal ledger and emits the same normalized facts for applications that need them elsewhere.

## Next Steps

* [Chat]({% link _getting_started/chat.md %}) - the core conversation interface these counts come from.
* [Model Registry]({% link _reference/models.md %}) - explore the registry and the `RubyLLM::Model` pricing fields behind `cost_for`.
* [Extended Thinking]({% link _core_features/thinking.md %}) - work with reasoning-capable models.
* [Instrumentation and Observability]({% link _advanced/instrumentation.md %}) - configure subscribers and custom instrumenters.
* [Persistence with acts_as]({% link _advanced/rails-persistence.md %}) - persist chats while RubyLLM manages the internal ledger.
* [Error Handling]({% link _advanced/error-handling.md %}) - recover from provider failures and configure fallbacks.

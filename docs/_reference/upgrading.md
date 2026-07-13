---
layout: default
title: Upgrading
nav_order: 4
description: How to upgrade to RubyLLM 2.0, step by step, plus every breaking change explained.
redirect_from:
  - /upgrading-to-1-7
  - /upgrading-to-1-7/
---

# {{ page.title }}
{: .no_toc }

{{ page.description }}
{: .fs-6 .fw-300 }

## Table of contents
{: .no_toc .text-delta }

1. TOC
{:toc}

This guide focuses on upgrade-impacting changes: migrations, token semantics, deprecations, and compatibility notes. It is not a complete changelog. For every feature, fix, and patch note, see the [GitHub releases](https://github.com/crmne/ruby_llm/releases).
{: .note }

---
# Upgrade to 2.0

2.0 is currently in development
{: .note }

Coming from 1.15 or earlier? Get to **1.16 first**, one minor version at a time, using the [1.16 upgrade guide](https://rubyllm.com/upgrading/); every older guide is in the version selector in the sidebar. This page covers only 1.16 to 2.0.
{: .important }

## What's New in 2.0

2.0 turns RubyLLM into a full framework. The 1.x line covered what you say to a model: chat, streaming, tools, structured output, embeddings, images, audio, extended thinking, agents, and thirteen providers behind one API. 2.0 owns what happens around the calls: the agentic loop as public API, tool approval, a per-attempt usage ledger, batches, durable execution, and Rails tables RubyLLM manages itself. One name for every concept, one architecture for every provider.

### New Capabilities

#### The Agentic Loop

* **Drive the loop yourself.** New loop verbs on chats and agents: `generate` makes one model call, `run_tools` executes pending tool calls, `step` does whichever is next, `complete?` says when the conversation is settled. See [Agentic Workflows]({% link _advanced/agentic-workflows.md %}#driving-the-loop-yourself).
* **Tool approval.** Declare `requires_approval` on a tool and the loop parks until `chat.approve!` or `chat.deny!` records a decision; in Rails the decision persists on the tool call record and survives restarts. See [Controlling Tool Execution]({% link _core_features/tool-execution.md %}#requiring-approval).
* **Model fallbacks.** `chat.with_fallbacks("backup-model")` retries the request on backup models when the primary fails. See [Model Fallbacks]({% link _advanced/error-handling.md %}#model-fallbacks).
* **Chat cancellation.** `chat.cancel!` stops a run from another thread; in Rails the request travels through the database, so a stop button in the web process halts a background job mid-stream. See [Cancelling a Background Stream]({% link _advanced/rails-streaming.md %}#cancelling-a-background-stream).

#### Accounting

* **Cost and usage tracking.** Every provider attempt lands in a usage ledger with frozen decimal costs, so retries, failures, and cancellations are accounted for truthfully. See [Cost and Usage Tracking]({% link _core_features/cost-and-usage-tracking.md %}).
* **Batch processing at half price.** Stage questions with `ask_later`, submit the chats with `RubyLLM.batch`, and collect the answers from any process. RubyLLM persists batch state internally in Rails. See [Batches]({% link _advanced/batches.md %}).
* **Prompt caching.** `with_caching` turns on the provider's automatic prompt cache; `cache_until_here!` marks an explicit prefix boundary. See [Prompt Caching]({% link _core_features/prompt-caching.md %}).

#### Content In, Content Out

* **Provider-managed files.** `RubyLLM.upload("manual.pdf")` uploads once so you can reuse the file across chats; large local attachments are promoted to provider files automatically (disable with `config.auto_upload_large_files = false`). See [Files]({% link _core_features/files.md %}).
* **Citations.** `chat.with_citations` makes attached documents and web sources citable, and every provider's native format is normalized into `RubyLLM::Citation` objects on `response.citations`. See [Citations]({% link _core_features/citations.md %}).
* **Text to speech.** `RubyLLM.speak("Hello!").save("hello.mp3")`. See [Text to Speech]({% link _core_features/text-to-speech.md %}).
* **Tools can return attachments.** Return an image or file from a tool and RubyLLM renders it to the model on every provider. See [Tools]({% link _core_features/tools.md %}).
* **Transcript replacement.** `chat.messages = messages_for_model` shows the LLM a different transcript from your users: compaction, redaction, moderation. See [Replacing the LLM Transcript]({% link _core_features/chat.md %}#advanced-replacing-the-llm-transcript).
* **Request hooks.** `chat.before_request { |payload| ... }` edits the wire payload just before it is sent - the 2.0 answer to raw content blocks. See [Request Hooks]({% link _core_features/chat-request-control.md %}#request-hooks).
* **Finish reasons.** `response.finish_reason` tells you why generation stopped, normalized across providers, with predicates like `stopped?` and `max_tokens?`.

#### Developer Experience

* **Prompt templates.** ERB prompts live in `app/prompts` and render through `RubyLLM::Prompt`; agents pick theirs up by convention. See [Prompt Rendering]({% link _core_features/prompt-rendering.md %}).
* **Instrumentation everywhere.** `paint`, `moderate`, and `transcribe` now emit `ActiveSupport::Notifications` events like chat and embed, and every one-shot API takes `metadata:` that flows into the event payload.
* **Output caps.** `with_max_output_tokens` bounds how much the model may generate.

### Provider Expansion

* **OpenAI defaults to the Responses API**, unlocking reasoning models with tools and extended thinking together. Details in [Providers and Protocols Split](#providers-and-protocols-split).
* **Vertex AI covers its full catalog**: Gemini, plus the Anthropic and Mistral models it hosts, each over its native protocol.
* **Gemini image models work in `paint`**, and `RubyLLM.moderate` accepts image inputs.
* **Bedrock** authenticates through AWS SDK credential providers (IAM roles, assume-role flows, rotating credentials) and accepts application inference profile ARNs as model ids.
* **The model registry is published** at [rubyllm.com/models.json](https://rubyllm.com/models.json), and `RubyLLM.models.refresh!` now persists what it fetches.
* **A provider generator** scaffolds a complete provider gem, specs and CI included: `ruby_llm provider-gem Acme --api-base https://api.acme.ai/v1`. See [Custom Providers]({% link _reference/custom-providers.md %}).

## How to Upgrade

The upgrade migration renames tables in place, backfills, and then removes legacy columns, and it has no `down`. Snapshot your database before you start, and rehearse the migration on a copy of production data.
{: .warning }

### 1. Finish what is in flight

Complete or cancel conversations parked mid-tool-round before migrating. 2.0 adds a unique index on `tool_call_id`, and the migration renumbers duplicated historical ids; finished rounds keep their links (they join by primary key), but a round waiting on its tool results is simplest to close out beforehand.

### 2. Bump the gem and run the generator

```bash
bundle update ruby_llm
bin/rails generate ruby_llm:upgrade
bin/rails db:migrate
```

The generated migration adds a boolean `cancelled` column to chats and citations, finish reasons, and prompt-cache boundaries to messages; moves the existing model, tool-call, and batch tables under RubyLLM's `ruby_llm_` prefix; converts model foreign keys into provider and model-id strings; renumbers duplicated `tool_call_id`s before adding the unique index; creates the usage ledger and backfills it from your messages' token and cost columns, one succeeded entry per message that recorded usage; and then removes those columns from your messages table. It stops with an explicit error if an old and a new version of the same supporting table both exist; reconcile those tables before retrying rather than allowing an ambiguous merge.

### 3. Delete what RubyLLM now owns

Applications own only chats and messages in 2.0. Remove the old `Model`, `ToolCall`, and `Batch` files from `app/models`; their tables have been renamed in place, so do not add a second migration to drop them. Remove `config.model_registry_class` and any `acts_as_model`, `acts_as_tool_call`, or `acts_as_batch` declarations. Everything they provided reads through RubyLLM now: `RubyLLM.models`, `message.tool_calls`, `message.tokens`, `chat.tokens`, `chat.cost`, `RubyLLM.batch`, and `RubyLLM::Batch.find`.

### 4. Fix the renames every app hits

Grep for each pattern on the left; the sections below the table explain the reasoning where the change is more than mechanical.

| Grep for | Change to |
|---|---|
| `input_tokens`, `output_tokens`, `cached_tokens`, `cache_creation_tokens`, `reasoning_tokens` | `tokens.input`, `tokens.output`, `tokens.cache_read`, `tokens.cache_write`, `tokens.thinking` on messages and responses; the message columns are gone and the ledger holds the counts |
| `RubyLLM::Content`, `content_raw` | `content` is always a String; files live on `message.attachments`; raw payload edits go through `before_request` |
| `create_user_message` | `ask_later` (stage and return self) or `add_message(role: :user, ...)` |
| `on_new_message`, `on_end_message`, `on_tool_call`, `on_tool_result` | `before_message`, `after_message`, `before_tool_call`, `after_tool_result` |
| `response.content` parsed as a Hash (structured output) | `response.parsed`; `content` is the JSON string |
| `display_name`, `max_tokens`, `input_price_per_million`, `supports_vision?`, `supports_functions?`, `Model::Info` | `name`, `max_output_tokens`, `price(:input)`, `supports?(:vision)`, `supports?(:function_calling)`, `RubyLLM::Model` |
| `with_params`, `params:` | `with_provider_options`, `provider_options:` |
| `halt`, `Tool::Halt` | the loop verbs (`step`, `complete?`) or [`requires_approval`]({% link _core_features/tool-execution.md %}#requiring-approval) |
| `with_tool(`, `with_tools(..., choice:` | `with_tools` for the set, `with_tool_options(choice:, calls:, concurrency:)` for the steering |
| Tool `desc `, `param :`, `params do` | `description`, `parameter`, `parameters` |
| `with_protocol` | `protocol:` on `chat`, `with_model`, or the agent `model` macro |

### 5. Boot, run your suite, and fix the UI edges

If you previously generated the Chat UI, update or regenerate its models controller and model views so they read `RubyLLM.models`, and its tool-call partial so it iterates `message.tool_calls.each_value` (the Hash is keyed by tool-call id, and the persisted records are `message.ruby_llm_tool_calls`). Rails' `dom_id` does not work on RubyLLM's internal tool-call records; build the id string yourself. The upgrade generator reports the exact generated files it detects.

### 6. Verify the money before you trust it

Cost and usage moved out of the transcript into a per-attempt ledger, and the migration backfilled it from your message rows. Before deleting any accounting of your own, reconcile: `chat.cost.total` and ledger sums (`SUM(total_cost)` on `ruby_llm_usage_entries`) should match what your old columns reported. Attempt costs are frozen decimals; keep pricing current for new attempts with a periodic `RubyLLM.models.refresh!`. See [Tokens and Costs]({% link _core_features/cost-and-usage-tracking.md %}).

## When Your App Outgrew the Defaults

The patterns below come from upgrading a production app that had grown its own model catalog, usage metering, and persisted formats on top of RubyLLM 1.x.

### App concerns on the model catalog

RubyLLM owns `ruby_llm_models` now, and the upgrade strips application columns from it. If your app decorated the old model table with its own concerns (availability toggles, a default flag, admin pricing overrides, slugs), move them to a settings table of your own that shadows the registry and re-syncs after every refresh:

```ruby
class ModelSetting < ApplicationRecord
  def self.refresh!
    RubyLLM.models.refresh!
    sync!
  end

  def self.sync!
    RubyLLM.models.each do |model|
      find_or_initialize_by(model_id: model.id, provider: model.provider)
        .update!(name: model.name, last_synced_at: Time.current)
    end
  end
end
```

Your rows carry the app's opinions; RubyLLM's rows carry the catalog. The migration for this split copies your old columns out before the upgrade strips them, so write it first and rehearse it.

### Your own usage ledger

If you metered usage with your own events table and per-user counters, the internal ledger replaces all of it. Reach it through associations and sum in SQL:

```ruby
class User < ApplicationRecord
  has_many :chats
  has_many :ruby_llm_usages, through: :chats
end

user.ruby_llm_usages.sum(:total_cost)
user.ruby_llm_usages.where("ruby_llm_usage_entries.created_at >= ?", period_start).sum(:total_cost)
```

Two things move with it: reconcile the ledger against your old totals before dropping your columns, and re-home any UI updates that hung off your old table's callbacks (a job-level `ensure` block is the usual landing spot), or those updates silently stop firing.

### Text you persisted before 2.0

Anything your app wrote to the database in a 1.x format needs a read path for old rows forever, not just through the migration. Parse the 2.0 format first and fall back:

```ruby
def search_sources(content)
  RubyLLM::SearchResults.from_content(content)&.results || legacy_regex_parse(content)
end
```

Pin the fallback with a test that feeds it a pre-2.0 row.

## Breaking Changes at a Glance

Scan the table for anything your app uses, then read its section below.

| Before | Now |
|---|---|
| `response.content` returning a Hash for structured output | `response.parsed` - `content` is the JSON string |
| `RubyLLM::Content`, raw content blocks | String `content` plus `message.attachments`; `before_request` hook |
| Tool `halt("done")`, `RubyLLM::Tool::Halt` | Loop verbs (`step`, `complete?`) or `with_tool_options` |
| `response.input_tokens`, `response.output_tokens` | `response.tokens.input`, `response.tokens.output` |
| `message.cached_tokens`, `message.cache_creation_tokens` | `message.tokens.cache_read`, `message.tokens.cache_write` |
| `message.reasoning_tokens`, `tokens.reasoning` | `message.tokens.thinking` |
| `message.tool_results` reading a tool message's text | `message.content` (`tool_results` now returns the answering messages) |
| Legacy `acts_as`, `config.use_new_acts_as` | Association-based `acts_as` only |
| `chat.reset_messages!` | `chat.messages = []` |
| `model.display_name`, `model.max_tokens` | `model.name`, `model.max_output_tokens` |
| `model.input_price_per_million` and friends | `model.price(:input)`, `:output`, `:cache_read`, `:cache_write` |
| `model.supports_vision?`, `model.supports_functions?` | `model.supports?(:vision)`, `model.supports?(:function_calling)` |
| `RubyLLM::Model::Info` | `RubyLLM::Model` |
| `config.model_registry_source` | `config.model_registry_store` |
| `on_new_message`, `on_end_message` | `before_message`, `after_message` |
| `on_tool_call`, `on_tool_result` | `before_tool_call`, `after_tool_result` |
| `with_instructions(text, replace: true)` | `with_instructions(text)` replaces by default |
| `schema do ... end` sniffing blocks | Schema DSL always; lambdas for dynamic schemas |
| `model.price(:cached_input)`, `cost.cache_creation` | `model.price(:cache_read)`, `cost.cache_write` |
| `with_model("gpt-5", assume_exists: true)` | `assume_model_exists:` |
| Tool `desc` / `param` / `params` | `description` / `parameter` / `parameters` |
| `response.model_id` | `response.model` |
| `Error.new(response, "msg")` | `Error.new("msg", response: response)` |
| `with_protocol(:responses)` | `protocol:` keyword on `chat`, `with_model`, agent `model` |
| `with_tool(Weather)` | `with_tools(Weather)` |
| `with_tools(W, choice: :required, calls: 3)` | `with_tools(W).with_tool_options(choice: :required, calls: 3)` |
| `create_user_message(content)` | `ask_later(content)` or `add_message(...)` |
| `with_params(...)`, `params:`, tool `with_params` | `with_provider_options(...)`, `provider_options:` |
| `transcribe(audio, response_format: "srt")` | `transcribe(audio, format: "srt")` |
| `Moderation#results` raw hashes | Typed `Moderation::Result` objects |

## Breaking Changes in Detail

### Message Content Is Always a String

`Message#content` now always returns the message text as a String (or nil) and is read-only. Attachments live on `message.attachments`. Structured output responses carry the JSON text in `content`; read the parsed Hash through `Message#parsed`:

```ruby
response = chat.with_schema(PersonSchema).ask("Generate a person")

response.content   # before - {"name" => "Alice", "age" => 30}
response.parsed    # now - {"name" => "Alice", "age" => 30}
response.content   # now - '{"name":"Alice","age":30}'
```

The `RubyLLM::Content` class and 1.9's raw content blocks (`RubyLLM::Content::Raw`) are gone. To inject provider-specific request content, edit the payload in the provider's own wire format just before it is sent:

```ruby
chat.before_request do |payload|
  payload[:messages] << { role: "user", content: [provider_specific_block] }
end
```

New installs no longer create the `content_raw` column; an existing column is left in place but unused. Tool results that return a Hash or Array now serialize as JSON text in the message content (previously Ruby `inspect` output).

### Token Readers

Token counts are exposed only through `#tokens`. The flattened `input_tokens`, `output_tokens`, `cache_read_tokens`, `cache_write_tokens`, and `thinking_tokens` readers were removed from messages, chunks, embeddings, and transcriptions. Replace them with the corresponding `RubyLLM::Tokens` readers. On Rails message records the old token and cost columns are moved into the usage ledger and dropped by the upgrade migration, so `message.tokens` is the only path there too:

```ruby
response.input_tokens        # before
response.tokens.input        # now

response.output_tokens       # before
response.tokens.output       # now

response.cache_read_tokens   # before
response.tokens.cache_read   # now
response.cache_write_tokens  # before
response.tokens.cache_write  # now
response.thinking_tokens     # before
response.tokens.thinking     # now
```

The `reasoning` synonyms are gone with them: `message.reasoning_tokens`, `tokens.reasoning`, and the `reasoning:` keyword on `Tokens.new` are all spelled `thinking` now.

### Message#tool_results Means the Answers

`Message#tool_results` changed meaning. It used to return a tool-result message's own content; it now returns the tool-result messages answering an assistant message's tool calls (an empty array when it made none), mirroring the `tool_results` association on `acts_as_message` records. Read a tool result's text with `message.content`.

### Legacy acts_as API

The legacy `acts_as` API and `config.use_new_acts_as` are gone. The association-based `acts_as` (the default since 1.7) is now the only API. **Remove `config.use_new_acts_as` from your initializer** - the option no longer exists, and an app that still sets it raises `NoMethodError` on boot. If you were still on the legacy API (`use_new_acts_as = false`), migrate your models to the association-based API (see [Upgrade to 1.7](#upgrade-to-17)) while on the latest 1.x, before upgrading.

### Chat Callbacks

The overriding `on_*` callbacks were removed. `on_new_message`, `on_end_message`, `on_tool_call`, and `on_tool_result` are gone. Use the additive Rails-style callbacks, which can be registered more than once and run alongside RubyLLM's own persistence callbacks:

```ruby
chat.before_message { ... }      # was on_new_message
chat.after_message { ... }       # was on_end_message
chat.before_tool_call { ... }    # was on_tool_call
chat.after_tool_result { ... }   # was on_tool_result
```

### Instructions Replace by Default

`with_instructions(replace:)` was removed. `with_instructions` replaces by default; pass `append: true` to add without replacing:

```ruby
chat.with_instructions("...", replace: true)   # before
chat.with_instructions("...")                  # now - replaces by default
chat.with_instructions("...", append: true)    # add another system message
```

### Agent Schema Blocks

Agent `schema` blocks are always the Schema DSL. A bare `schema do ... end` block is always interpreted as a [RubyLLM::Schema]({% link _core_features/structured-output.md %}). For a schema computed from the agent's inputs at runtime, pass a lambda:

```ruby
schema do                                            # Schema DSL - static shape
  string :answer
end

schema -> { strict ? StrictSchema : LooseSchema }    # dynamic - evaluated per run
```

### Cache Naming

Cache naming is `cache_read` / `cache_write` everywhere. The `cached_input*` / `cache_creation*` aliases on `Cost` and `Model` were removed in favor of `cache_read*` / `cache_write*` (e.g. `model.price(:cache_read)`, `cost.cache_read`). Token counts now follow: `tokens.cached` and `tokens.cache_creation` are gone (`tokens.cache_read` / `tokens.cache_write`), and `message.cached_tokens` / `message.cache_creation_tokens` are gone (`message.tokens.cache_read` / `message.tokens.cache_write`). The upgrade generator renames the Rails columns to match.

### One Model API

`RubyLLM::Model::Info` is now simply `RubyLLM::Model`, and model metadata has one name per fact:

```ruby
model.display_name                        # before
model.name                                # now

model.max_tokens                          # before
model.max_output_tokens                   # now

model.input_price_per_million             # before
model.price(:input)                       # now - also :output,
                                          # :cache_read, :cache_write

model.supports_vision?                    # before
model.supports?(:vision)                  # now

model.supports_functions?                 # before
model.supports?(:function_calling)        # now - same for :structured_output,
                                          # :batch, :reasoning, :citations,
                                          # :streaming, :video
```

Tool-steering support is a registry capability too: query `model.supports?(:tool_choice)` and `model.supports?(:parallel_tool_calls)` instead of the removed provider predicates. Registry entries expose the same API through `RubyLLM.models`; application-owned `acts_as_model` records no longer exist.

### One Name per Concept

2.0 renames the remaining stragglers so each concept has a single name across the gem:

```ruby
chat.with_model("gpt-5", assume_exists: true)      # before
chat.with_model("gpt-5", assume_model_exists: true) # now - same name as RubyLLM.chat

class Weather < RubyLLM::Tool
  desc "Gets current weather"                       # before
  description "Gets current weather"                # now
  param :city, desc: "City name"                    # before
  parameter :city, description: "City name"         # now
  params do ... end                                 # before (whole-schema form)
  parameters do ... end                             # now
end

response.model_id                                   # before
response.model                                      # now - matches Embedding,
image.model                                         # Transcription, and Moderation

chat.reset_messages!                                # before
chat.messages = []                                  # now - the transcript setter
```

### Error Constructors

Error constructors take the message first. `RubyLLM::Error.new` no longer takes the response as the first positional argument (and no longer guesses whether a String argument is a message). The message comes first, matching `StandardError`, and the response is a keyword: `RateLimitError.new("slow down", response: response)`.

Two hierarchy notes: `UnsupportedAttachmentError` now inherits from `RubyLLM::Error` (it was a bare `StandardError`), so a `rescue RubyLLM::Error` catches it; and malformed tool-call JSON from a provider raises the new `RubyLLM::ToolCallParseError` instead of a raw `JSON::ParserError`.

### Protocol Joins Model Selection

Protocol is part of model selection. A model is identified by its name, provider, and wire protocol, so `protocol:` joins `provider:` as a keyword of `RubyLLM.chat`, `with_model`, and the agent `model` macro. The standalone `with_protocol` / `without_protocol` methods are gone:

```ruby
RubyLLM.chat(model: 'gpt-5.4').with_protocol(:responses)   # before
RubyLLM.chat(model: 'gpt-5.4', protocol: :responses)       # now

chat.with_model('gpt-5.4', protocol: :chat_completions)    # override on an existing chat

class Support < RubyLLM::Agent
  model 'gpt-5.4', provider: :openai, protocol: :responses
end
```

Passing no `protocol:` uses the provider's default for that model (still overridable globally with `config.openai_protocol`). A bare `with_model('other')` resets the protocol to the default, the same way it re-resolves the provider.

### Tools: One Method for the Set, One for the Options

`with_tool` (singular) is gone; `with_tools` takes one or many. The `replace:` flag is gone (replacing is a chain). And the `choice:` / `calls:` / `concurrency:` keywords moved off `with_tools` into `with_tool_options`, so declaring tools and steering how they run are separate calls:

```ruby
chat.with_tool(Weather)                                  # before
chat.with_tools(Weather)                                 # now

chat.with_tools(Search, Calculator, replace: true)       # before
chat.with_tools(nil).with_tools(Search, Calculator)      # now

chat.with_tools(Weather, choice: :required, calls: 3)    # before
chat.with_tools(Weather).with_tool_options(choice: :required, calls: 3)  # now
```

`with_tools(nil)` clears the set; passing `nil` options to `with_tool_options` resets choice, call limit, and concurrency. On agents the same split applies: the `tools` macro declares the set, the new `tool_options` macro carries `choice:` / `calls:` / `concurrency:` (previously `tools choice: :required` silently wiped the toolset).

### Tools No Longer Halt the Loop

`RubyLLM::Tool::Halt` and the protected `halt(message)` helper are gone; a tool cannot terminate the conversation loop from inside anymore. Control belongs to the caller now: bound tool execution with `with_tool_options` (see [Tool Execution]({% link _core_features/tool-execution.md %})), or stop on your own condition by driving the loop yourself:

```ruby
class Escalate < RubyLLM::Tool
  def execute
    halt("Handing off to a human")     # before
    "Handing off to a human"           # now - just a result
  end
end

chat.generate                          # one model call
chat.run_tools                         # execute pending tool calls
break if done_condition                # your halt, outside the tool
chat.step until chat.complete?         # or let it run to completion
```

See [Driving the Loop Yourself]({% link _advanced/agentic-workflows.md %}#driving-the-loop-yourself) and [Agent Handoffs]({% link _advanced/agentic-workflows.md %}#agent-handoffs) for the patterns that replace halting, including mid-conversation handoff to another agent.

### create_user_message Removed

Use `ask_later` (returns the chat, for staging) or `add_message(role: :user, content:, with:)` (returns the record).

### Tool.provider_options nil Raises

Passing `nil` to the class macro was a no-op clear that made no sense on a class; it now raises. Call it with a hash to set provider metadata.

### Zero Prices Mean Free

`model.pricing` used to drop 0.0 prices, making a free model indistinguishable from one with no pricing data. Zero now flows through as a real price (`cost.total` returns `0.0`); `nil` means the registry has no price.

### The Model Registry Has a Store

`config.model_registry_source` is now `config.model_registry_store` - an object responding to `read`, and optionally `write(registry)` for persistence. `config.model_registry_file` defaults to a per-user OS cache path instead of the gem's bundled JSON. `RubyLLM.models.refresh!` now does the whole job: it fetches the published registry from [rubyllm.com/models.json](https://rubyllm.com/models.json), merges models discovered from your configured providers, updates the registry in place, and persists the result to the store - raising `RubyLLM::ModelRegistryError` and leaving the registry untouched when the fetch fails. The old provider-API rebuild survives as `refresh_from_providers!` for registry maintainers.

### The provider_options Escape Hatch

Options in the provider's request vocabulary that RubyLLM does not abstract go through one named door, everywhere. `with_params` and the `params:` keyword are gone:

```ruby
chat.with_params(service_tier: "flex")              # before
chat.with_provider_options(service_tier: "flex")    # now (reader: chat.provider_options)

RubyLLM.embed(text, params: { dimensions: 512 })            # before
RubyLLM.embed(text, provider_options: { dimensions: 512 })  # now - same on paint,
                                                            # transcribe, moderate

class Weather < RubyLLM::Tool
  with_params cache_control: { type: "ephemeral" }          # before
  provider_options cache_control: { type: "ephemeral" }     # now
end

class Support < RubyLLM::Agent
  params service_tier: "flex"                       # before
  provider_options service_tier: "flex"             # now
end
```

Instrumentation subscribers: the event payload key `:params` is now `:provider_options`.

`provider_options` is merged into the request verbatim, in the provider's own request shapes. RubyLLM no longer relocates, scrubs, or reinterprets provider-specific fields on the way through, so you write exactly what the provider documents (Amazon Nova's `top_k`, for example, is `additionalModelRequestFields: { inferenceConfig: { topK: ... } }`, its real nesting; the old code silently dropped a flat `top_k` here).

### Media Signatures Carry Only Shared Concepts

`RubyLLM.transcribe` keeps `model:`, `language:`, `prompt:`, `temperature:`, and gains `format:` (the transcript format, provider-native values: `"diarized_json"` on OpenAI, a MIME type on Gemini) plus `speaker_names:` / `speaker_references:` (transcription-domain concepts; providers that cannot identify speakers ignore them). Wire-level knobs left the signature: OpenAI's `timestamp_granularities` and `chunking_strategy`, Gemini's `max_output_tokens` and `safety_settings` are passed through `provider_options:` in each provider's own request shape:

```ruby
RubyLLM.transcribe("call.wav", response_format: "srt")   # before
RubyLLM.transcribe("call.wav", format: "srt")            # now

RubyLLM.transcribe("talk.wav",
  provider_options: { timestamp_granularities: ["word"] })            # OpenAI
RubyLLM.transcribe("talk.wav", model: "gemini-2.5-flash",
  provider_options: { generationConfig: { maxOutputTokens: 1000 } })  # Gemini
```

`RubyLLM.embed` gains `task_type:` and `title:` for task-typed embeddings (query vs document vs classification). Like `format:`, the value is provider-native and lands in the right place for each provider (VertexAI `task_type` per instance, Gemini `taskType` per request, Bedrock Cohere `input_type`); you no longer hand-build the `instances:` array:

```ruby
RubyLLM.embed(chunks, model: "gemini-embedding-001",
              task_type: "RETRIEVAL_DOCUMENT", title: "Handbook")
```

### Typed Results

Results are typed, not raw provider hashes. `Moderation#results` returns `Moderation::Result` objects (`flagged?`, `categories`, `category_scores`) instead of string-keyed OpenAI hashes, the top-level helpers aggregate consistently across all results, and the misleading `Moderation#content` alias is gone. `Image#usage` is no longer public; use `image.tokens` and `image.cost`. `Tool.parameters` as a public reader is gone (it is the whole-schema macro now); tools declare their arguments, they do not expose them.

### Tool-Building Gems

Gems that build tools programmatically (for example ruby_llm-mcp) need the same renames: `param` is `parameter`, `params` is `parameters`, `with_params` is `provider_options`.

## Providers and Protocols Split

RubyLLM 2.0 separates providers (host, auth, catalog) from protocols (wire format). The public chat API is unchanged - `RubyLLM.chat`, `embed`, `paint`, and the Rails integration all work as before. Two things changed underneath:

**OpenAI now defaults to the Responses API.** This unlocks reasoning models with tools and extended thinking together. To stay on Chat Completions:

```ruby
RubyLLM.configure do |config|
  config.openai_protocol = :chat_completions
end

# or per chat, as part of model selection
RubyLLM.chat(model: 'gpt-5.4', protocol: :chat_completions)
```

If you pass Chat Completions-only options via `with_provider_options` (like `response_format`), either switch those chats to `:chat_completions` or use the Responses API equivalents (`text: { format: ... }`).

Function tools keep their Chat Completions behavior on the Responses API: RubyLLM sends `strict: false` explicitly because the Responses API otherwise defaults to strict schema validation, which forces the model to fill in every parameter — including ones you declared optional. To opt a tool into strict validation, declare `provider_options strict: true` on the tool class and make sure its schema meets the [strict mode requirements](https://platform.openai.com/docs/guides/function-calling#strict-mode) (every property in `required`, optional parameters expressed as nullable types).

**Wire-format internals moved to `RubyLLM::Protocols`.** `RubyLLM::Providers::OpenAI::Chat` and sibling modules are now `RubyLLM::Protocols::ChatCompletions::Chat` and friends; Anthropic, Gemini, and Bedrock Converse internals moved the same way. Provider classes no longer inherit from each other (`Mistral < OpenAI` is gone) - a provider declares its protocols instead. Providers also no longer override `#name`: the human name is `display_name` and the identifier is the registration-derived `slug`.

If you maintain a provider gem, subclass a protocol for your dialect and declare it in a thin provider:

```ruby
class MyProvider < RubyLLM::Provider
  class ChatCompletions < RubyLLM::Protocols::ChatCompletions
    # your overrides
  end

  protocol :chat_completions, ChatCompletions
end
```

For routing details and per-chat overrides, see [Choosing the Wire Protocol]({% link _core_features/chat-request-control.md %}#choosing-the-wire-protocol).

# Older Upgrade Guides

Every 1.x upgrade lives in the docs for its release. Use the version selector in the sidebar, or start from the [1.16 upgrade guide](https://rubyllm.com/upgrading/), and step through one minor version at a time, clearing deprecations before the next.

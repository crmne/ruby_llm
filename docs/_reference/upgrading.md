---
layout: default
title: Upgrading
nav_order: 4
description: Upgrade guides for changes in data formats
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

Upgrade one minor version at a time.
{: .important }

RubyLLM follows the same discipline as Rails itself: bump one release at a time, run that release's migrations, and clear any deprecations before moving on. If you're several versions behind, get to the **latest 1.x first** (each section below documents what changed and ships the generator for that step), then upgrade to 2.0. RubyLLM 2.0 carries a single `ruby_llm:upgrade` generator that always targets the current release - it does not bundle the older per-version generators.

2.0 in one breath: a wave of new capabilities (batches, files, citations, prompt caching, speech, fallbacks, cancellation), one architecture for talking to providers (providers declare wire protocols), one name for every concept in the API, and a Rails integration where RubyLLM owns its own tables. The rest of this section unpacks each part.

## What's New in 2.0

### New Capabilities

* **Batch processing at half price.** Stage questions with `ask_later`, submit the chats with `RubyLLM.batch`, and collect the answers from any process. RubyLLM persists batch state internally in Rails. See [Batches]({% link _advanced/batches.md %}).
* **Provider-managed files.** `RubyLLM.upload("manual.pdf")` uploads once so you can reuse the file across chats; large local attachments are promoted to provider files automatically (disable with `config.auto_upload_large_files = false`). See [Files]({% link _core_features/files.md %}).
* **Drive the loop yourself.** New loop verbs on chats and agents: `generate` makes one model call, `run_tools` executes pending tool calls, `step` does whichever is next, `complete?` says when the conversation is settled. See [Agentic Workflows]({% link _advanced/agentic-workflows.md %}#driving-the-loop-yourself).
* **Tool approval.** Declare `requires_approval` on a tool and the loop parks until `chat.approve!` or `chat.deny!` records a decision; in Rails the decision persists on the tool call record and survives restarts. See [Controlling Tool Execution]({% link _core_features/tool-execution.md %}#requiring-approval).
* **Citations.** `chat.with_citations` makes attached documents and web sources citable, and every provider's native format is normalized into `RubyLLM::Citation` objects on `response.citations`. See [Citations]({% link _core_features/citations.md %}).
* **Prompt caching.** `with_caching` turns on the provider's automatic prompt cache; `cache_until_here!` marks an explicit prefix boundary. See [Prompt Caching]({% link _core_features/prompt-caching.md %}).
* **Text to speech.** `RubyLLM.speak("Hello!").save("hello.mp3")`. See [Text to Speech]({% link _core_features/text-to-speech.md %}).
* **Model fallbacks.** `chat.with_fallbacks("backup-model")` retries the request on backup models when the primary fails. See [Model Fallbacks]({% link _advanced/error-handling.md %}#model-fallbacks).
* **Chat cancellation.** `chat.cancel!` stops a run from another thread; in Rails the request travels through the database, so a stop button in the web process halts a background job mid-stream. See [Cancelling a Background Stream]({% link _advanced/rails-streaming.md %}#cancelling-a-background-stream).
* **Transcript replacement.** `chat.messages = messages_for_model` shows the LLM a different transcript from your users: compaction, redaction, moderation. See [Replacing the LLM Transcript]({% link _core_features/chat.md %}#advanced-replacing-the-llm-transcript).
* **Prompt templates.** ERB prompts live in `app/prompts` and render through `RubyLLM::Prompt`; agents pick theirs up by convention. See [Prompt Rendering]({% link _core_features/prompt-rendering.md %}).
* **Tools can return attachments.** Return an image or file from a tool and RubyLLM renders it to the model on every provider. See [Tools]({% link _core_features/tools.md %}).
* **Request hooks.** `chat.before_request { |payload| ... }` edits the wire payload just before it is sent - the 2.0 answer to raw content blocks. See [Request Hooks]({% link _core_features/chat-request-control.md %}#request-hooks).
* **Finish reasons.** `response.finish_reason` tells you why generation stopped, normalized across providers, with predicates like `stopped?` and `max_tokens?`.
* **Instrumentation everywhere.** `paint`, `moderate`, and `transcribe` now emit `ActiveSupport::Notifications` events like chat and embed, and every one-shot API takes `metadata:` that flows into the event payload.
* **Cost and usage tracking.** Every provider attempt lands in a usage ledger with frozen decimal costs, so retries, failures, and cancellations are accounted for truthfully. See [Cost and Usage Tracking]({% link _core_features/cost-and-usage-tracking.md %}).
* **Output caps.** `with_max_output_tokens` bounds how much the model may generate.

### Provider Expansion

* **OpenAI defaults to the Responses API**, unlocking reasoning models with tools and extended thinking together. Details in [Providers and Protocols Split](#providers-and-protocols-split).
* **Vertex AI covers its full catalog**: Gemini, plus the Anthropic and Mistral models it hosts, each over its native protocol.
* **Gemini image models work in `paint`**, and `RubyLLM.moderate` accepts image inputs.
* **Bedrock** authenticates through AWS SDK credential providers (IAM roles, assume-role flows, rotating credentials) and accepts application inference profile ARNs as model ids.
* **The model registry is published** at [rubyllm.com/models.json](https://rubyllm.com/models.json), and `RubyLLM.models.refresh!` now persists what it fetches.
* **A provider generator** scaffolds a complete provider gem, specs and CI included: `ruby_llm provider-gem Acme --api-base https://api.acme.ai/v1`. See [Custom Providers]({% link _reference/custom-providers.md %}).

## How to Upgrade

```bash
# After bumping the gem to 2.0
bin/rails generate ruby_llm:upgrade
bin/rails db:migrate
```

The generator adds a boolean `cancelled` column to chats, moves the existing model, tool-call, and batch tables under RubyLLM's `ruby_llm_` prefix, and creates the usage ledger. The chat keeps its model foreign key, renamed to `ruby_llm_model_id` and pointed at RubyLLM's internal model table; legacy message model references become provider/model strings. The migration backfills the ledger from your messages' token and cost columns, one succeeded entry per message that recorded usage, and then removes those columns from your messages table. It also normalizes tool-call links and adds citations, finish reasons, and prompt-cache boundaries to messages. It stops with an explicit error if an old and new version of the same supporting table both exist; reconcile those tables before retrying rather than allowing an ambiguous merge.

**Cost and usage tracking moved out of the transcript.** A message can have several provider attempts after transport retries, while failed and cancelled attempts may have no message. Usage and cost calculations read the internal ledger; the upgrade migration backfills it from your existing message rows. Attempt costs are frozen in normalized decimal columns. See [Cost and Usage Tracking]({% link _core_features/cost-and-usage-tracking.md %}) and keep pricing current with a periodic `RubyLLM.models.refresh!`.

**Applications now own only chats and messages.** RubyLLM owns the supporting model, tool-call, usage, and batch records. After migrating, remove the old `Model`, `ToolCall`, and `Batch` files from `app/models`; their tables have been renamed in place, so do not add a second migration to drop them. Remove `config.model_registry_class` and any `acts_as_model`, `acts_as_tool_call`, or `acts_as_batch` declarations. Use `RubyLLM.models`, `message.tool_calls`, `message.tokens`, `chat.tokens`, `chat.cost`, `RubyLLM.batch`, and `RubyLLM::Batch.find` instead.

If you previously generated the Chat UI, update or regenerate its models controller and model views so they read `RubyLLM.models`, and its tool-call partial so it iterates `message.tool_calls.each_value`. The upgrade generator reports the exact generated files it detects. Review custom code that queries `Model`, `ToolCall`, or `Batch` directly before restarting the application.

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

---
# Upgrade to 1.15

## How to Upgrade

No generator is required for the token and cost API changes in 1.15.

If you use the Rails integration and already ran the v1.9 migration, no new columns are needed. The new `cache_read_tokens` and `cache_write_tokens` helpers use the existing `cached_tokens` and `cache_creation_tokens` columns.

## Token Semantics Changed

RubyLLM now normalizes prompt cache usage before exposing token counts. From 1.15 onward, `response.tokens.input` means standard input tokens. When a provider includes cache reads or cache writes in its raw prompt token total, RubyLLM subtracts those cache buckets and exposes them separately.

Use the new cache names in new code:

```ruby
response.tokens.input
response.tokens.output
response.tokens.cache_read
response.tokens.cache_write
```

RubyLLM 1.15 also retained the older top-level token helpers. RubyLLM 2.0 removes them; use the `tokens` value shown above.

The still older `cached_tokens` and `cache_creation_tokens` aliases are removed as well.

If your app stored or displayed provider raw prompt totals, reconstruct the request-side input activity by adding the normalized buckets:

```ruby
request_side_input_tokens =
  response.tokens.input.to_i +
  response.tokens.cache_read.to_i +
  response.tokens.cache_write.to_i
```

For costs, prefer the new cost helpers instead of multiplying token totals yourself:

```ruby
response.cost.total
chat.cost.total
agent.cost.total
```

Cost helpers are available from 1.15 onward. They return `nil` for any cost bucket whose pricing is missing, and `cost.total` is also `nil` when a used bucket has incomplete pricing.

`tokens.thinking` remains available from 1.10. From 1.15 onward, `tokens.output` is normalized as the billable output bucket. Do not add `tokens.thinking` to `tokens.output` yourself; RubyLLM includes thinking in output when the provider bills it as output, and exposes `cost.thinking` only for models with distinct reasoning-token pricing.

See [Tokens and Costs]({% link _core_features/cost-and-usage-tracking.md %}#how-providers-are-normalized) for the provider comparison table and the exact normalized token semantics RubyLLM exposes.

# Upgrade to 1.14

## How to Upgrade

```bash
bin/rails generate ruby_llm:upgrade_to_v1_14
bin/rails db:migrate
```

That's it! The generator:
- Changes `thought_signature` on tool calls from `string` to `text`
- Prevents thought signature truncation issues on MySQL/MariaDB

## What's New in 1.14

Among other features:

- Safer Gemini thought signature persistence for Rails apps using ActiveRecord

# Upgrade to 1.10

## How to Upgrade

```bash
bin/rails generate ruby_llm:upgrade_to_v1_10
bin/rails db:migrate
```

That's it! The generator:
- Adds `thinking_text` and `thinking_signature` for storing extended thinking output
- Adds `thinking_tokens` for tracking thinking token usage
- Adds `thought_signature` to tool calls for Gemini 3 Pro function calling

## What's New in 1.10

Among other features:

- Extended thinking support across providers with optional persistence
- Thinking token tracking when providers report it

# Upgrade to 1.9

## How to Upgrade

```bash
bin/rails generate ruby_llm:upgrade_to_v1_9
bin/rails db:migrate
```

That's it! The generator:
- Adds the `cached_tokens` and `cache_creation_tokens` columns for tracking accessed cached tokens and created cache tokens respectively.
- Adds the `content_raw` column for the Raw Content Blocks feature (replaced in 2.0 by the [`before_request` hook]({% link _core_features/chat-request-control.md %}#request-hooks))

## What's New in 1.9

Among other features:

- Raw Content Blocks to pass provider-specific content verbatim to an LLM (replaced in 2.0 by the [`before_request` hook]({% link _core_features/chat-request-control.md %}#request-hooks)).
- Cached token tracking to accurately track costs given cache hits

# Upgrade to 1.7

Upgrade to the DB-backed model registry for better data integrity and rich model metadata.

## How to Upgrade

### From 1.6 to 1.7 (2 commands)

```bash
bin/rails generate ruby_llm:upgrade_to_v1_7
bin/rails db:migrate
```

That's it! The generator:
- Creates the models table if needed
- Automatically adds `config.use_new_acts_as = true` to your initializer
- Automatically updates your existing models' `acts_as` declarations to the new version
- Migrates your existing data to use foreign keys
- Loads the models in the db
- Preserves all your data (old string columns renamed to `model_id_string`)

### Custom Model Names

If you're using custom model names:

```bash
bin/rails generate ruby_llm:upgrade_to_v1_7 chat:Conversation message:ChatMessage tool_call:MyToolCall model:MyModel
bin/rails db:migrate
```

### What happens without upgrading

Your existing 1.6 app continues working without any changes. You'll see a deprecation warning on Rails boot:

```
!!! RubyLLM's legacy acts_as API is deprecated and will be removed in RubyLLM 2.0.0.
```

You can silence or raise RubyLLM deprecations while upgrading:

```ruby
RubyLLM.configure do |config|
  config.deprecation_behavior = :silence # or :raise
end
```

## What's New in 1.7

Among other features, the DB-backed model registry replaces simple string fields with proper ActiveRecord associations. Additionally, the `acts_as` helpers have been redesigned with a more Rails-like API.

### Available with DB-backed Model Registry
{: .d-inline-block }

v1.7.0+
{: .label .label-green }

**New Rails-like `acts_as` API**
```ruby
# New API uses Rails association names as primary parameters
acts_as_chat messages: :messages, model: :model
acts_as_message chat: :chat, tool_calls: :tool_calls, model: :model

# vs Legacy API which required explicit class names
acts_as_chat message_class: 'Message', tool_call_class: 'ToolCall'
acts_as_message chat_class: 'Chat', chat_foreign_key: 'chat_id'
```

**Rich model metadata**
```ruby
chat.model.name              # => "GPT-4"
chat.model.context_window    # => 128000
chat.model.supports_vision   # => true
chat.model.input_token_cost  # => 2.50
```

**Provider routing**
```ruby
Chat.create!(model: "{{ site.models.anthropic_current }}", provider: "bedrock")
```

**Model associations and queries**
```ruby
Chat.joins(:model).where(models: { provider: 'anthropic' })
Model.select { |m| m.supports?(:function_calling) }  # Use delegated methods
```

**Model alias resolution**
```ruby
Chat.create!(model: "{{ site.models.default_chat }}", provider: "openrouter")  # Resolves to openai/{{ site.models.default_chat }} automatically
```

**Usage tracking**
```ruby
Model.joins(:chats).group(:id).order('COUNT(chats.id) DESC')
```

### Available without Model Registry
{: .d-inline-block }

Legacy mode
{: .label .label-yellow }

**Legacy `acts_as` API** - Still uses the old parameter style
```ruby
acts_as_chat message_class: 'Message', tool_call_class: 'ToolCall'
acts_as_message chat_class: 'Chat', tool_call_class: 'ToolCall'
```

**Basic functionality** - All core RubyLLM features work
```ruby
chat.ask("Hello!")  # Works fine
chat.model_id  # => "{{ site.models.openai_standard }}" (string only, no metadata)
```

**Limited to:**
- String-based model IDs only
- Default provider routing

## If You Have Custom Model Names

If you're using custom model names (e.g., `Conversation` instead of `Chat`), you may need to update your `acts_as` declarations to the new API:

**Before (1.6):**
```ruby
class Conversation < ApplicationRecord
  acts_as_chat message_class: 'ChatMessage', tool_call_class: 'AiToolCall'
end

class ChatMessage < ApplicationRecord
  acts_as_message chat_class: 'Conversation', chat_foreign_key: 'conversation_id'
end
```

**After (1.7):**
```ruby
class Conversation < ApplicationRecord
  acts_as_chat messages: :chat_messages  # Association name
end

class ChatMessage < ApplicationRecord
  acts_as_message chat: :conversation,  # Association name
                  tool_calls: :ai_tool_calls
end
```

The new API follows Rails association inference. Association names determine default foreign keys; class options only change the class name. For example, `tool_calls: :ai_tool_calls` uses `ai_tool_call_id`, while `tool_call_class: 'AiToolCall'` by itself still uses `tool_call_id`.

## New Chat UI Generator

### Instant Chat Interface
{: .d-inline-block }

v1.7.0+
{: .label .label-green }

Add a fully-functional chat UI to your Rails app with Turbo streaming:

```bash
# Default model names
bin/rails generate ruby_llm:chat_ui

# Or with custom model names (same as install generator)
bin/rails generate ruby_llm:chat_ui chat:Conversation message:ChatMessage model:LLMModel
```

This creates:
- Complete chat controller with streaming responses
- Turbo-powered views with real-time updates
- Styled chat interface (messages, input, model selector)
- File attachment support
- Token usage tracking
- Copy-to-clipboard functionality

The chat UI works with your existing Chat and Message models and includes:
- Model selection dropdown
- Real-time streaming responses
- Markdown rendering
- Code syntax highlighting
- Responsive design

## New Applications

Fresh installs get the model registry automatically:

```bash
bin/rails generate ruby_llm:install
bin/rails db:migrate

# Optional: Add chat UI
bin/rails generate ruby_llm:chat_ui
```

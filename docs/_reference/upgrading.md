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

## How to Upgrade

```bash
# After bumping the gem to 2.0
bin/rails generate ruby_llm:upgrade
bin/rails db:migrate
```

The generator adds a JSON `citations` column and string `finish_reason` column to your messages table so [citations]({% link _core_features/citations.md %}) and provider stop reasons are persisted with each assistant message. It also adds `cache_until_here` for [prompt caching]({% link _core_features/prompt-caching.md %}), a `total_cost` and `cost_details` pair that freezes each message's [cost]({% link _reference/model-costs.md %}) at completion, creates the `batches` table for [provider-side batches]({% link _advanced/batches.md %}), and renames the cache token columns (`cached_tokens` to `cache_read_tokens`, `cache_creation_tokens` to `cache_write_tokens`). The new columns are optional - without them, citations and finish reasons stay on in-memory responses, cache boundaries stay on in-memory messages, costs are recomputed live, and batches aren't persisted.

**Persisted costs are frozen at completion.** With the `total_cost` and `cost_details` columns, `message.cost` returns the cost recorded when the message completed instead of recomputing from current registry pricing, so refreshing the model registry no longer rewrites the cost of past chats. `total_cost` is a plain numeric column you can aggregate in SQL (`chat.messages.sum(:total_cost)`). Because history is now frozen, keep pricing current for new messages with a periodic `RubyLLM.models.refresh!` (see [Model Costs]({% link _reference/model-costs.md %})).

## Breaking Changes

**The legacy `acts_as` API and `config.use_new_acts_as` are gone.** The association-based `acts_as` (the default since 1.7) is now the only API. **Remove `config.use_new_acts_as` from your initializer** - the option no longer exists, and an app that still sets it raises `NoMethodError` on boot. If you were still on the legacy API (`use_new_acts_as = false`), migrate your models to the association-based API (see [Upgrade to 1.7](#upgrade-to-17)) while on the latest 1.x, before upgrading.

**The overriding `on_*` callbacks were removed.** `on_new_message`, `on_end_message`, `on_tool_call`, and `on_tool_result` are gone. Use the additive Rails-style callbacks, which can be registered more than once and run alongside RubyLLM's own persistence callbacks:

```ruby
chat.before_message { ... }      # was on_new_message
chat.after_message { ... }       # was on_end_message
chat.before_tool_call { ... }    # was on_tool_call
chat.after_tool_result { ... }   # was on_tool_result
```

**`with_instructions(replace:)` was removed.** `with_instructions` replaces by default; pass `append: true` to add without replacing:

```ruby
chat.with_instructions("...", replace: true)   # before
chat.with_instructions("...")                  # now - replaces by default
chat.with_instructions("...", append: true)    # add another system message
```

**Agent `schema` blocks are always the Schema DSL.** A bare `schema do ... end` block is always interpreted as a [RubyLLM::Schema]({% link _core_features/structured-output.md %}). For a schema computed from the agent's inputs at runtime, pass a lambda:

```ruby
schema do                                            # Schema DSL - static shape
  string :answer
end

schema -> { strict ? StrictSchema : LooseSchema }    # dynamic - evaluated per run
```

**Cache naming is `cache_read` / `cache_write` everywhere.** The `cached_input*` / `cache_creation*` aliases on `Cost`, `Model`, and `acts_as_model` records were removed in favor of `cache_read*` / `cache_write*` (e.g. `model.price(:cache_read)`, `cost.cache_read`). Token counts now follow: `tokens.cached` and `tokens.cache_creation` are gone (`tokens.cache_read` / `tokens.cache_write`), and `message.cached_tokens` / `message.cache_creation_tokens` are gone (`message.cache_read_tokens` / `message.cache_write_tokens`). The upgrade generator renames the Rails columns to match.

**One name per concept.** 2.0 renames the remaining stragglers so each concept has a single name across the gem:

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
```

**Error constructors take the message first.** `RubyLLM::Error.new` no longer takes the response as the first positional argument (and no longer guesses whether a String argument is a message). The message comes first, matching `StandardError`, and the response is a keyword: `RateLimitError.new("slow down", response: response)`.

**Clearing settings uses `without_*`, on every setting.** The nil sentinels are gone; passing `nil` to any `with_*` raises an ArgumentError pointing at the `without_*` sibling:

```ruby
chat.with_tools(nil)            # before
chat.without_tools              # now

chat.with_thinking(nil)         # before
chat.without_thinking           # now

chat.with_instructions(nil)     # before (destroyed persisted system messages on records!)
chat.without_instructions       # now - same effect, stated intent
```

The full family on Chat (mirrored on `acts_as_chat` records and agents): `without_tools`, `without_thinking`, `without_instructions`, `without_citations`, `without_temperature`, `without_schema`, `without_caching`, `without_provider_options`, `without_headers`, `without_fallbacks`, and `without_context`.

**Protocol is part of model selection.** A model is identified by its name, provider, and wire protocol, so `protocol:` joins `provider:` as a keyword of `RubyLLM.chat`, `with_model`, and the agent `model` macro. The standalone `with_protocol` / `without_protocol` methods are gone:

```ruby
RubyLLM.chat(model: 'gpt-5.4').with_protocol(:responses)   # before
RubyLLM.chat(model: 'gpt-5.4', protocol: :responses)       # now

chat.with_model('gpt-5.4', protocol: :chat_completions)    # override on an existing chat

class Support < RubyLLM::Agent
  model 'gpt-5.4', provider: :openai, protocol: :responses
end
```

Passing no `protocol:` uses the provider's default for that model (still overridable globally with `config.openai_protocol`). A bare `with_model('other')` resets the protocol to the default, the same way it re-resolves the provider.

**Tools: one method for the set, one for the options.** `with_tool` (singular) is gone; `with_tools` takes one or many. The `replace:` flag is gone (replacing is a chain). And the `choice:` / `calls:` / `concurrency:` keywords moved off `with_tools` into `with_tool_options`, so declaring tools and steering how they run are separate calls:

```ruby
chat.with_tool(Weather)                                  # before
chat.with_tools(Weather)                                 # now

chat.with_tools(Search, Calculator, replace: true)       # before
chat.without_tools.with_tools(Search, Calculator)        # now

chat.with_tools(Weather, choice: :required, calls: 3)    # before
chat.with_tools(Weather).with_tool_options(choice: :required, calls: 3)  # now
```

`without_tools` clears the set; `without_tool_options` resets choice, call limit, and concurrency. On agents the same split applies: the `tools` macro declares the set, the new `tool_options` macro carries `choice:` / `calls:` / `concurrency:` (previously `tools choice: :required` silently wiped the toolset).

**`create_user_message` was removed.** Use `ask_later` (returns the chat, for staging) or `add_message(role: :user, content:, with:)` (returns the record).

**`Tool.provider_options nil` raises.** Passing `nil` to the class macro was a no-op clear that made no sense on a class; it now raises. Call it with a hash to set provider metadata.

**Zero prices mean free.** `model.pricing` used to drop 0.0 prices, making a free model indistinguishable from one with no pricing data. Zero now flows through as a real price (`cost.total` returns `0.0`); `nil` means the registry has no price.

**The escape hatch is called `provider_options`.** Options in the provider's request vocabulary that RubyLLM does not abstract go through one named door, everywhere. `with_params` and the `params:` keyword are gone:

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

**Shared media signatures carry only shared concepts.** `RubyLLM.transcribe` keeps `model:`, `language:`, `prompt:`, `temperature:`, and gains `format:` (the transcript format, provider-native values: `"diarized_json"` on OpenAI, a MIME type on Gemini) plus `speaker_names:` / `speaker_references:` (transcription-domain concepts; providers that cannot identify speakers ignore them). Wire-level knobs left the signature: OpenAI's `timestamp_granularities` and `chunking_strategy`, Gemini's `max_output_tokens` and `safety_settings` are passed through `provider_options:` in each provider's own request shape:

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

**Results are typed, not raw provider hashes.** `Moderation#results` returns `Moderation::Result` objects (`flagged?`, `categories`, `category_scores`) instead of string-keyed OpenAI hashes, the top-level helpers aggregate consistently across all results, and the misleading `Moderation#content` alias is gone. `Image#usage` is no longer public; use `image.tokens` and `image.cost`. `Tool.parameters` as a public reader is gone (it is the whole-schema macro now); tools declare their arguments, they do not expose them.

**Gems that build tools programmatically** (for example ruby_llm-mcp) need the same renames: `param` is `parameter`, `params` is `parameters`, `with_params` is `provider_options`.

## Providers and Protocols Split

RubyLLM 2.0 separates providers (host, auth, catalog) from protocols (wire format). The public chat API is unchanged - `RubyLLM.chat`, `with_params`, `embed`, `paint`, and the Rails integration all work as before. Two things changed underneath:

**OpenAI now defaults to the Responses API.** This unlocks reasoning models with tools and extended thinking together. To stay on Chat Completions:

```ruby
RubyLLM.configure do |config|
  config.openai_protocol = :chat_completions
end

# or per chat, as part of model selection
RubyLLM.chat(model: 'gpt-5.4', protocol: :chat_completions)
```

If you pass Chat Completions-only options via `with_provider_options` (like `response_format`), either switch those chats to `:chat_completions` or use the Responses API equivalents (`text: { format: ... }`).

**Wire-format internals moved to `RubyLLM::Protocols`.** `RubyLLM::Providers::OpenAI::Chat` and sibling modules are now `RubyLLM::Protocols::ChatCompletions::Chat` and friends; Anthropic, Gemini, and Bedrock Converse internals moved the same way. Provider classes no longer inherit from each other (`Mistral < OpenAI` is gone) - a provider declares its protocols instead.

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

The top-level token helpers still work for backwards compatibility:

```ruby
response.input_tokens       # Same as tokens.input
response.output_tokens      # Same as tokens.output
response.cache_read_tokens  # Same as tokens.cache_read
response.cache_write_tokens # Same as tokens.cache_write
response.cached_tokens          # Same as cache_read_tokens
response.cache_creation_tokens  # Same as cache_write_tokens
```

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

See [Tracking Token Usage]({% link _core_features/chat-tokens.md %}#tracking-token-usage) for the provider comparison table and the exact normalized token semantics RubyLLM exposes.

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
- Adds the `content_raw` column for the new [Raw Content Blocks]({% link _core_features/chat-request-control.md %}#raw-content-blocks) feature

## What's New in 1.9

Among other features:

- [Raw Content Blocks]({% link _core_features/chat-request-control.md %}#raw-content-blocks) to pass provider-specific content verbatim to an LLM.
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

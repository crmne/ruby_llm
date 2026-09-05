---
layout: default
title: Upgrading
nav_order: 4
description: Upgrade from RubyLLM 1.16 to 2.0 with phased migrations, recovery planning, and API changes.
redirect_from:
  - /upgrading-to-1-7
  - /upgrading-to-1-7/
---

# {{ page.title }}

{{ page.description }}
{: .fs-6 .fw-300 }

This guide focuses on upgrade-impacting changes: migrations, token semantics, deprecations, and compatibility notes. It is not a complete changelog. For every feature, fix, and patch note, see the [GitHub releases](https://github.com/crmne/ruby_llm/releases).
{: .note }

---
# Upgrade to 2.0

This guide covers RubyLLM 2.0.0.rc1.
{: .note }

Coming from 1.15 or earlier? Get to **1.16 first**, one minor version at a time, using the [1.16 upgrade guide](https://rubyllm.com/upgrading/); every older guide is in the version selector in the sidebar. This page covers only 1.16 to 2.0.
{: .important }

RubyLLM 2.0 adds control over the conversation loop, tool approvals, usage accounting for each provider attempt, and persisted batches. Applications continue to own chats and messages. RubyLLM owns the supporting model, tool-call, usage, and batch tables.

This guide covers the database upgrade and breaking API changes. For usage examples, see [Agentic Workflows]({% link _advanced/agentic-workflows.md %}), [Tool Execution]({% link _core_features/tool-execution.md %}), [Cost and Usage Tracking]({% link _core_features/cost-and-usage-tracking.md %}), and [Batches]({% link _advanced/batches.md %}).

## How to Upgrade

The generator creates three migrations for one runtime cutover. Keep affected requests and background activity paused until all three phases and your application-specific conversions finish. Preparation changes table names and associations that 1.x needs. A partial backfill cannot support normal 2.0 operation.
{: .warning }

| Phase | Purpose |
| --- | --- |
| Prepare | Checks the 1.16 schema, moves supporting tables, and adds the 2.0 columns and indexes. |
| Backfill | Converts message content, tool results, and historical usage in batches, with database checkpoints. |
| Finish | Verifies the converted records, enforces required constraints, and marks the upgrade complete. |
| Cleanup | Removes legacy message columns in a later deployment. Generate this phase separately. |

Each phase can resume after an interruption while affected activity remains paused. The generator supports the schema produced by RubyLLM 1.16. Upgrade older applications to 1.16 first, and review any differences in application-specific schemas before proceeding.

Rehearse the exact candidate against an isolated recent production snapshot. Record the duration of each phase, lock waits, row counts, preserved token and cost totals, and the result of stopping and restarting the backfill. Preparation includes index creation, type normalization, and any required tool-call ID repair; measure it as well as the data backfill.

### 1. Finish what is in flight

Complete or cancel conversations parked mid-tool-round before migrating. The backfill converts each 1.16 message-to-tool-call result link into the polymorphic link used by 2.0. A completed round has both sides of that relationship; an unfinished round does not.

### 2. Bump the gem and run the generator

```bash
bundle add ruby_llm --version 2.0.0.rc1
bin/rails generate ruby_llm:upgrade
```

The initializer 1.16 wrote sets `config.use_new_acts_as`, and older apps may set `config.model_registry_class`. 2.0 ignores both with a deprecation warning, so the app boots and the generator can run. Remove the two lines once you are on 2.0.

Pass every application model that uses a non-default name. The generator accepts `chat`, `message`, `model`, and `tool_call` mappings, including namespaced classes:

```bash
bin/rails generate ruby_llm:upgrade \
  chat:AI::Chat \
  message:AI::Chat::Message \
  model:AI::LLMModel \
  tool_call:AI::Chat::ToolCall
```

The command prints the resolved classes and tables before writing anything. It rejects unknown, incomplete, and duplicate mappings, so a typo cannot silently send an irreversible migration to the default table.

Before production, update the application declarations and API calls described below and test the candidate artifact. At the start of the maintenance window, drain requests and jobs, stop scheduled jobs and retries, and establish a verified database recovery point. Run the three phases, load the packaged model registry with `bin/rails ruby_llm:load_models`, and reconcile the converted records before restarting processes and restoring traffic. `load_models` needs no network; `RubyLLM.models.refresh` fetches current metadata later.

The generated migrations:

* Add cancellation state to chats, and citations, server-tool replay data, raw reasoning, finish reasons, and prompt-cache boundaries to messages.
* Rename the model and tool-call tables with the `ruby_llm_` prefix and create usage and batch tables.
* Rename the chat's model reference to `ruby_llm_model_id` and copy message-level model identity into the usage ledger.
* Add approval and thinking metadata to tool-call records.
* Copy `content_raw` into `raw_content` and write its JSON representation to `content` when `content` is `NULL`.
* Create one succeeded usage entry for each historical assistant response or other message with recorded usage, preserving the available token and cost fields.

If a usage candidate has neither a message model nor a chat model, preparation stops before changing the schema and names the record to repair. RubyLLM 1.16 did not store costs by default. If your application added `total_cost` or the supported `cost_details` fields, the backfill preserves them. Otherwise, historical costs remain unknown.

The generator owns RubyLLM's supporting tables and its legacy message columns. Audit application-owned logs, evaluations, approvals, accounting, and foreign keys separately. Reconcile application-specific conversions before reopening the affected functionality.

#### Running Phases Separately

Generate one phase at a time when a backfill needs explicit scheduling:

```bash
bin/rails generate ruby_llm:upgrade --phase prepare
bin/rails generate ruby_llm:upgrade --phase backfill
bin/rails generate ruby_llm:upgrade --phase finish
```

Pass the same model mappings to every invocation. These commands write ordinary Rails migration files; `bin/rails db:migrate` runs all pending files. Generating separate files alone does not move the backfill out of your deployment's release phase.

For a platform with a release-phase timeout, arrange for the candidate artifact to be available under maintenance and disable its automatic migration command for this cutover. Run the generated migrations from an operator process outside that release phase, using `bin/rails db:migrate:up VERSION=...` in timestamp order. Restore the usual migration command after the cutover. If you use an application data-migration runner, preserve the backfill's batch transactions, checkpoints, and verification, and prevent concurrent runners.

The backfill processes 10,000 messages per batch and reports the task and last committed primary key. Each batch commits its writes and checkpoint together. Retrying skips completed ranges and does not duplicate historical usage. Keep all affected readers and writers paused through preparation, backfill, finish, and application-specific reconciliation.

### 3. Delete what RubyLLM now owns

Applications own only chats and messages in 2.0. Remove the old `Model` and `ToolCall` files from `app/models`. Their tables have been renamed in place, so do not add a second migration to drop them. Remove `config.model_registry_class` and any `acts_as_model` or `acts_as_tool_call` declarations. Also strip the removed keywords from the two macros that stay: `acts_as_chat` keeps only `messages:`, `message_class:`, and `messages_foreign_key:`, and `acts_as_message` keeps `chat:`, `chat_class:`, `chat_foreign_key:`, and `touch_chat:`. A leftover `model:` or `tool_calls:` option raises `ArgumentError` on boot. Everything they provided reads through RubyLLM now: `RubyLLM.models`, `message.tool_calls`, `message.tokens`, `chat.tokens`, `chat.cost`, `RubyLLM.batch`, and `RubyLLM::Batch.find`.

### 4. Fix the renames every app hits

Grep for each pattern on the left; the sections below the table explain the reasoning where the change is more than mechanical.

| Grep for | Change to |
|---|---|
| `input_tokens`, `output_tokens`, `cached_tokens`, `cache_creation_tokens`, `reasoning_tokens` | `tokens.input`, `tokens.output`, `tokens.cache_read`, `tokens.cache_write`, `tokens.thinking` on messages and responses; the ledger holds the counts and cleanup removes the old message columns |
| `RubyLLM::Content`, `content_raw` | `content` is always a String; files live on `message.attachments`; raw payload edits go through `before_request` |
| `create_user_message` | `ask_later` (stage and return self) or `add_message(role: :user, ...)` |
| `on_new_message`, `on_end_message`, `on_tool_call`, `on_tool_result` | `before_message`, `after_message`, `before_tool_call`, `after_tool_result` |
| `response.content` parsed as a Hash (structured output) | `response.parsed`; `content` is the JSON string |
| `display_name`, `max_tokens`, `input_price_per_million`, `supports_vision?`, `supports_functions?`, `Model::Info` | `name`, `max_output_tokens`, `price(:input)`, `supports?(:vision)`, `supports?(:function_calling)`, `RubyLLM::Model` |
| `with_params`, `params:` | `with_provider_options`, `provider_options:` |
| `tool.call({ city: "Berlin" })` | `tool.call(city: "Berlin")` |
| `halt`, `Tool::Halt` | the loop verbs (`step`, `complete?`) or [`requires_approval`]({% link _core_features/tool-execution.md %}#requiring-approval) |
| `with_tool(`, `with_tools(..., choice:` | `with_tools` for the set, `with_tool_options(choice:, calls:, concurrency:)` for the steering |
| Tool `desc `, `param :`, `params do` | `description`, `parameter`, `parameters` |
| `RubyLLM.models.refresh!`, `load_from_json!`, `load_from_database!`, `Model.refresh!` | `RubyLLM.models.refresh`, `load_from_json`, `load_from_store`; the registry has no application model |
| `RubyLLM.models.find(id, :openai)` | `RubyLLM.models.find(id, provider: :openai)` |
| `finish_reason == "stop"`, `finish_reason == "end_turn"` | `finish_reason == :stop`; every protocol maps its own values onto `:stop`, `:max_tokens`, `:tool_calls`, and `:content_filter` |

### 5. Boot, run your suite, and fix the UI edges

If you previously generated the Chat UI, update or regenerate its models controller and model views so they read `RubyLLM.models`, and its tool-call partial so it iterates `message.tool_calls.each_value` (the Hash is keyed by tool-call id, and the persisted records are `message.ruby_llm_tool_calls`). Rails' `dom_id` does not work on RubyLLM's internal tool-call records; build the id string yourself. `bin/rails generate ruby_llm:chat_ui --force` regenerates every chat UI file at once.

### 6. Reconcile Usage and Costs

Compare historical message and tool-result counts, token buckets, and available cost totals against your pre-upgrade baselines. The ledger has one succeeded entry per historical usage candidate because 1.16 did not retain individual retry attempts. Do not invent attempt boundaries or costs that the old data cannot establish.

If your application has its own accounting tables, reconcile them before removing their source data. New attempt costs are frozen decimals. Refresh model metadata periodically for subsequent calls. See [Cost and Usage Tracking]({% link _core_features/cost-and-usage-tracking.md %}).

### 7. Remove Legacy Columns Later

After the observation period, generate the cleanup migration with the same model mappings:

```bash
bin/rails generate ruby_llm:upgrade --phase cleanup
```

Review it, then run `bin/rails db:migrate` in a later deployment. Cleanup refuses to run until the finish phase has recorded a successful upgrade. It removes the legacy message model and tool-call references, `content_raw`, token columns, supported cost columns, and the temporary backfill checkpoint table.

Retained columns are recovery evidence. RubyLLM 2.0 does not keep them synchronized with new messages. The finish phase relaxes legacy reference constraints so new messages can be written before cleanup. Review any application-specific constraints and defaults as part of rehearsal.

### Recovery and Rollback

All four phases raise `ActiveRecord::IrreversibleMigration` on `down`. Renaming tables back would not reconstruct the old data contract: 2.0 records individual provider attempts, frozen costs, approvals, and new tool-result relationships. Returning that data to 1.x would be lossy.

If a phase fails, keep affected activity paused and either repair the cause and retry, or restore the verified pre-upgrade database together with the previous application artifact. A failed release can leave committed schema changes behind, so reverting application code alone is unsafe. Rehearse the recovery procedure and agree on its acceptable data-loss window before production. If recovery restores the whole database, account for unrelated writes that would also be lost.

## When Your App Outgrew the Defaults

The patterns below come from upgrading a production app that had grown its own model catalog, usage metering, and persisted formats on top of RubyLLM 1.x.

### App concerns on the model catalog

RubyLLM owns `ruby_llm_models` now. The upgrade preserves extra application columns physically rather than discarding data, but RubyLLM does not maintain or provide an API for them. If your app decorated the old model table with its own concerns (availability toggles, a default flag, admin pricing overrides, slugs), move them to a settings table of your own that shadows the registry and re-syncs after every refresh:

```ruby
class ModelSetting < ApplicationRecord
  def self.refresh
    RubyLLM.models.refresh
    sync
  end

  def self.sync
    RubyLLM.models.each do |model|
      find_or_initialize_by(model_id: model.id, provider: model.provider)
        .update!(name: model.name, last_synced_at: Time.current)
    end
  end
end
```

Your rows carry the app's opinions; RubyLLM's rows carry the catalog. The generated upgrade preserves your extra columns, so copy them into your settings table in an application migration and remove them from `ruby_llm_models` only after you reconcile the new rows.

### Your own usage ledger

If you metered usage with your own events table and per-user counters, the internal ledger can become the accounting source for provider attempts. Reach it through associations and sum in SQL:

```ruby
class User < ApplicationRecord
  has_many :chats
  has_many :ruby_llm_usages, through: :chats
end

user.ruby_llm_usages.sum(:total_cost)
user.ruby_llm_usages.where("ruby_llm_usages.created_at >= ?", period_start).sum(:total_cost)
```

Keep your application ledger if it also represents customer billing, credits, quotas, or adjustments that RubyLLM cannot know about. Otherwise, reconcile the internal ledger against your old totals before dropping your columns, and re-home any UI updates that hung off your old table's callbacks (a job-level `ensure` block is the usual landing spot), or those updates silently stop firing.

### Text you persisted before 2.0

The migration copies each 1.16 `content_raw` value into `raw_content` and writes its JSON representation to `content` when `content` is `NULL`. This preserves structured output without guessing whether the request used a schema. The later cleanup migration removes `content_raw`; inspect application-specific values during rehearsal and move anything that needs a different representation in an application migration.

Anything your app wrote to the database in a 1.x format needs a read path for old rows forever, not just through the migration. Parse the 2.0 format first and fall back:

```ruby
def search_sources(content)
  parse_v2_sources(content) || legacy_regex_parse(content)
end
```

Pin the fallback with a test that feeds it a pre-2.0 row.

## Breaking Changes at a Glance

Scan the table for anything your app uses, then read its section below.

| Before | Now |
|---|---|
| `response.content` returning a Hash for structured output | `response.parsed` - `content` is the JSON string |
| `RubyLLM::Content`, raw content blocks | String `content` plus `message.attachments`; `before_request` hook |
| `RubyLLM::Schema` | `Schematist::Schema` |
| Tool `halt("done")`, `RubyLLM::Tool::Halt` | Loop verbs (`step`, `complete?`) or `with_tool_options` |
| `response.input_tokens`, `response.output_tokens` | `response.tokens.input`, `response.tokens.output` |
| `message.cached_tokens`, `message.cache_creation_tokens` | `message.tokens.cache_read`, `message.tokens.cache_write` |
| `message.reasoning_tokens`, `tokens.reasoning` | `message.tokens.thinking` |
| `RubyLLM::Tokens.build(...)` | `RubyLLM::Tokens.new(...)`; preserve the old all-`nil` guard yourself if it mattered |
| `cost.tokens`, `cost.model`, `cost.category` | Read tokens and model from the result; `Cost` exposes priced amounts only |
| `message.tool_results` reading a tool message's text | `message.content` (`tool_results` now returns the answering messages) |
| Legacy `acts_as`, `config.use_new_acts_as` | Association-based `acts_as` only |
| `chat.reset_messages!` | `chat.messages = []` |
| `model.display_name`, `model.max_tokens` | `model.name`, `model.max_output_tokens` |
| `model.input_price_per_million` and friends | `model.price(:input)`, `:output`, `:cache_read`, `:cache_write` |
| `pricing_category[:batch]`, `pricing_tier[:input_per_million]`, tier price writers | `pricing_category.batch`, `pricing_tier.input_per_million`; rebuild registry data instead of mutating it |
| `model.supports_vision?`, `model.supports_functions?` | `model.supports?(:vision)`, `model.supports?(:function_calling)` |
| `RubyLLM::Model::Info` | `RubyLLM::Model` |
| `config.model_registry_source` | `config.model_registry_store` |
| `RubyLLM::ModelRegistry::JsonSource`, `RubyLLM::ModelRegistry::ActiveRecordSource` | `config.model_registry_file`, or a `model_registry_store` object; Rails configures its store automatically |
| `RubyLLM.models.load_from_database!` | `RubyLLM.models.load_from_store` |
| `RubyLLM.models.refresh!`, `RubyLLM.models.load_from_json!` | `RubyLLM.models.refresh`, `RubyLLM.models.load_from_json` |
| `RubyLLM.models.find(id, :openai)` | `RubyLLM.models.find(id, provider: :openai)` |
| `response.finish_reason` as a provider String (`"end_turn"`, `"STOP"`) | a Symbol normalized across providers: `:stop`, `:max_tokens`, `:tool_calls`, `:content_filter` |
| `chat.thinking` returning `{effort: "low"}`, `model.type` returning `"chat"` | Symbols: `{effort: :low}`, `:chat` |
| `RubyLLM.ocr(file, table_format: "html")`, `RubyLLM.upload(file, display_name:)` | `provider_options: { table_format: "html" }`, `provider_options: { display_name: }`; shared concepts such as `pages:`, `uri:`, and `content_type:` stay keywords |
| `batch.provider_slug`, `fallback.provider` as a Symbol | `batch.provider`, `fallback.provider` as a String, like every other provider reader |
| `on_new_message`, `on_end_message` | `before_message`, `after_message` |
| `on_tool_call`, `on_tool_result` | `before_tool_call`, `after_tool_result` |
| `with_instructions(text, replace: true)` | `with_instructions(text)` replaces by default |
| `schema do ... end` sniffing blocks | Schema DSL always; lambdas for dynamic schemas |
| `model.cached_input_price_per_million`, `cost.cache_creation` | `model.price(:cache_read)`, `cost.cache_write` |
| `with_model("gpt-5", assume_exists: true)` | `assume_model_exists:` |
| Tool `desc` / `param` / `params` | `description` / `parameter` / `parameters` |
| Tool `provider_params` and `params_schema` readers | `provider_options` and `parameters_schema` |
| `response.model_id`, `image.model_id` | `response.model`, `image.model` |
| `Error.new(response, "msg")` | `Error.new("msg", response: response)` |
| `with_tool(Weather)` | `with_tools(Weather)` |
| `with_tools(W, choice: :required, calls: :one)` | `with_tools(W).with_tool_options(choice: :required, calls: :one)` |
| `create_user_message(content)` | `ask_later(content)` or `add_message(...)` |
| `with_params(...)`, `params:`, tool `with_params` | `with_provider_options(...)`, `provider_options:` |
| `transcribe(audio, response_format: "srt")` | `transcribe(audio, format: "srt")` |
| `Moderation#results` raw hashes | Typed `Moderation::Result` objects |
| `Moderation#categories` | `moderation.flagged_categories`, or categories on each typed result |
| `Moderation#content`, `Image#usage`, Tool `#parameters` reader | `Moderation#results`, `image.tokens` / `image.cost`, no public reader |
| Bare `Agent.instructions` requiring its conventional prompt | Named agents load it automatically when present; use `instructions { prompt("instructions") }` to require it |
| `attachment.save(path)` | `File.binwrite(path, attachment.content)` |
| Temperature rewritten to `1.0` or dropped for some models | The temperature you set is the temperature sent |

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

New installs no longer create the `content_raw` column, and the upgrade migrations move its values into `raw_content` before removing it. Tool results that return a Hash or Array now serialize as JSON text in the message content (previously Ruby `inspect` output).

### Token Readers

Token counts are exposed only through `#tokens`. The flattened `input_tokens`, `output_tokens`, `cache_read_tokens`, `cache_write_tokens`, and `thinking_tokens` readers were removed from messages, chunks, embeddings, and transcriptions. Replace them with the corresponding `RubyLLM::Tokens` readers. On Rails message records the old token and cost columns are moved into the usage ledger and dropped by the upgrade migrations, so `message.tokens` is the only path there too:

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

`RubyLLM::Tokens.build` was also removed. Construct `RubyLLM::Tokens` directly. In 1.16, `build` returned `nil` when every count was `nil`; preserve that guard in caller code if you depended on the sentinel:

```ruby
counts.values.all?(&:nil?) ? nil : RubyLLM::Tokens.new(**counts)
```

`Cost` is now only the priced value: `input`, `output`, `cache_read`, `cache_write`, `thinking`, `total`, and `to_h`. Its old `tokens`, `model`, and `category` construction-input readers are gone. Read the tokens and model from the result that owns the cost, or retain those inputs yourself when constructing a cost directly.

### Message#tool_results Means the Answers

`Message#tool_results` changed meaning. It used to return a tool-result message's own content; it now returns the tool-result messages answering an assistant message's tool calls (an empty array when it made none), mirroring the `tool_results` association on `acts_as_message` records. Read a tool result's text with `message.content`.

### Legacy acts_as API

The legacy `acts_as` API and `config.use_new_acts_as` are gone. The association-based `acts_as` (the default since 1.7) is now the only API. **Remove `config.use_new_acts_as` from your initializer.** Its compatibility setter logs a deprecation warning and ignores the value so the upgrade generator can run. It does not restore the legacy API. If you were still on the legacy API (`use_new_acts_as = false`), migrate your models to the association-based API (see the [1.16 upgrade guide](https://rubyllm.com/upgrading/)) while on the latest 1.x, before upgrading.

### Chat Callbacks

The overriding `on_*` callbacks were removed. `on_new_message`, `on_end_message`, `on_tool_call`, and `on_tool_result` are gone. Use the additive Rails-style callbacks, which can be registered more than once and run alongside RubyLLM's own persistence callbacks:

```ruby
chat.before_message { puts "Receiving a message" }           # was on_new_message
chat.after_message { |message| puts message.content }        # was on_end_message
chat.before_tool_call { |tool_call| puts tool_call.name }     # was on_tool_call
chat.after_tool_result { |result| puts result }              # was on_tool_result
```

### Instructions Replace by Default

`with_instructions(replace:)` was removed. `with_instructions` replaces by default; pass `append: true` to add without replacing:

```ruby
chat.with_instructions("...", replace: true)   # before
chat.with_instructions("...")                  # now - replaces by default
chat.with_instructions("...", append: true)    # add another system message
```

### Agent Schema Blocks

Agent `schema` blocks are always the Schema DSL. A bare `schema do ... end` block is always interpreted as a [Schematist schema]({% link _core_features/structured-output.md %}). For a schema computed from the agent's inputs at runtime, pass a lambda:

```ruby
schema do                                            # Schema DSL - static shape
  string :answer
end

schema -> { strict ? StrictSchema : LooseSchema }    # dynamic - evaluated per run
```

### RubyLLM::Schema Is Now Schematist

The JSON Schema DSL moved from the `ruby_llm-schema` gem and `RubyLLM::Schema` constant to the general-purpose `schematist` gem and `Schematist::Schema`. RubyLLM installs the dependency, but classes that inherit from the old constant need the new name:

```ruby
# Before
class PersonSchema < RubyLLM::Schema
  string :name
end

# Now
class PersonSchema < Schematist::Schema
  string :name
end
```

Tool and agent `parameters do` / `schema do` blocks keep the same DSL. The schema generator emits `Schematist::Schema` in 2.0.

### Cache Naming

Cache naming is `cache_read` / `cache_write` everywhere. The `cached_input*` / `cache_creation*` aliases on `Cost`, `Model`, `PricingCategory`, and `PricingTier` were removed in favor of `cache_read*` / `cache_write*` (e.g. `model.price(:cache_read)`, `cost.cache_read`, `category.cache_read_input`, `tier.cache_read_input_per_million`). Token counts now follow: `tokens.cached` and `tokens.cache_creation` are gone (`tokens.cache_read` / `tokens.cache_write`), and `message.cached_tokens` / `message.cache_creation_tokens` are gone (`message.tokens.cache_read` / `message.tokens.cache_write`). The upgrade generator backfills the ledger under the new bucket names. The later cleanup phase drops the old message columns.

### One Model API

`RubyLLM::Model::Info` is now `RubyLLM::Model`, and model metadata has one name per fact:

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

The pricing tree is read-only in 2.0. Use the named readers (`pricing_category.standard`, `pricing_category.batch`, `pricing_tier.input_per_million`) instead of `#[]`, and change the registry data used to build a model instead of assigning prices through `PricingTier` writers.

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
  params do                                        # before (whole-schema form)
    string :city
  end
  parameters do                                    # now
    string :city
  end
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

Protocol is part of model selection, new in 2.0. A model is identified by its name, provider, and wire protocol, so `protocol:` joins `provider:` as a keyword of `RubyLLM.chat`, `with_model`, and the agent `model` macro:

```ruby
RubyLLM.chat(model: 'gpt-5.4', protocol: :chat_completions)

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

chat.with_tools(Weather, choice: :required, calls: :one)    # before
chat.with_tools(Weather).with_tool_options(choice: :required, calls: :one)  # now
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

loop do
  chat.step
  break if chat.complete? || chat.awaiting_approval? || done_condition
end
```

See [Driving the Loop Yourself]({% link _advanced/agentic-workflows.md %}#driving-the-loop-yourself) and [Agent Handoffs]({% link _advanced/agentic-workflows.md %}#agent-handoffs) for the patterns that replace halting, including mid-conversation handoff to another agent.

### create_user_message Removed

Use `ask_later` (returns the chat, for staging) or `add_message(role: :user, content:, attachments:)` (returns the record).

### Tool.provider_options nil Raises

Passing `nil` to the class macro was a no-op clear that made no sense on a class; it now raises. Call it with a hash to set provider metadata.

### Zero Prices Mean Free

`model.pricing` used to drop 0.0 prices, making a free model indistinguishable from one with no pricing data. Zero now flows through as a real price (`cost.total` returns `0.0`); `nil` means the registry has no price.

### The Model Registry Has a Store

`config.model_registry_source` is now `config.model_registry_store` - an object responding to `read`, and optionally `write(registry)` for persistence. The old `RubyLLM::ModelRegistry::JsonSource` and `RubyLLM::ModelRegistry::ActiveRecordSource` wrappers are gone: set `config.model_registry_file` for the file fallback, assign your own store object when you need one, or let the Rails integration configure its internal database store. Accordingly, `RubyLLM.models.load_from_database!` is now `RubyLLM.models.load_from_store`. `config.model_registry_file` defaults to a per-user OS cache path instead of the gem's bundled JSON. `RubyLLM.models.refresh` now does the whole job: it fetches the published registry from [rubyllm.com/models.json](https://rubyllm.com/models.json), merges models discovered from your configured providers, updates the registry in place, and persists the result to the store - raising `RubyLLM::ModelRegistryError` and leaving the registry untouched when the fetch fails. The old provider-API rebuild survives as `refresh_from_providers` for registry maintainers.

### Agent Prompt Convention

In 1.16, calling the bare `instructions` class macro made an agent require its conventional `instructions.txt.erb` prompt. In 2.0, a named agent loads that prompt automatically when it exists, while bare `instructions` is only the reader for the configured value. Require the file explicitly when a missing prompt should fail:

```ruby
class WorkAssistant < RubyLLM::Agent
  instructions { prompt("instructions") }
end
```

### Attachment Saving

`Attachment#save` was removed. To copy a local or inline attachment's bytes, use `File.binwrite(path, attachment.content)`.

### The provider_options Escape Hatch

Options in the provider's request vocabulary that RubyLLM does not abstract go through one named door, everywhere. `with_params` and the `params:` keyword are gone:

```ruby
chat.with_params(service_tier: "flex")              # before
chat.with_provider_options(service_tier: "flex")    # now (reader: chat.provider_options)

RubyLLM.paint(prompt, params: { quality: "hd" })            # before
RubyLLM.paint(prompt, provider_options: { quality: "hd" })  # now - same on embed,
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

### Temperature Goes Out As You Set It

RubyLLM 1.x rewrote the temperature to `1.0` for OpenAI reasoning models, dropped it for search preview models, and dropped it for anything the model registry marked as refusing sampling parameters. Those rules disagreed with the providers often enough to hide real errors and to override values models would have honored.

2.0 sends what you set. RubyLLM still sends no temperature until you set one, so nothing changes for chats that leave it alone. If you set a temperature a model rejects, you now get the provider's `RubyLLM::BadRequestError` instead of a silently altered request. Drop the `with_temperature` call for those models and let them use their own default.

### Typed Results

Results are typed, not raw provider hashes. `Moderation#results` returns `Moderation::Result` objects (`flagged?`, `categories`, `category_scores`) instead of string-keyed OpenAI hashes, the top-level helpers aggregate consistently across all results, and the misleading `Moderation#content` alias is gone. The old top-level `Moderation#categories` hash is gone too; use `moderation.flagged_categories` for the combined flagged names, or inspect each typed result. `Image#usage` is no longer public; use `image.tokens` and `image.cost`. `Tool.parameters` as a public reader is gone (it is the whole-schema macro now); tools declare their arguments, they do not expose them.

### Tool-Building Gems

Gems that build tools programmatically (for example ruby_llm-mcp) need the same renames: `param` is `parameter`, `params` is `parameters`, `with_params` is `provider_options`.

## Providers and Protocols Split

RubyLLM 2.0 separates providers (host, auth, catalog) from protocols (wire format). The `RubyLLM.chat`, `embed`, and `paint` entry points remain. Apply the signature changes in this guide when upgrading. Two protocol changes also affect existing applications:

**OpenAI now defaults to the Responses API.** The Responses API supports reasoning, tools, and extended thinking in the same request. To stay on Chat Completions:

```ruby
RubyLLM.configure do |config|
  config.openai_protocol = :chat_completions
end

# or per chat, as part of model selection
RubyLLM.chat(model: 'gpt-5.4', protocol: :chat_completions)
```

If you pass Chat Completions-only options via `with_provider_options` (like `response_format`), either switch those chats to `:chat_completions` or use the Responses API equivalents (`text: { format: ... }`).

Function tools keep their Chat Completions behavior on the Responses API: RubyLLM sends `strict: false` explicitly because the Responses API otherwise defaults to strict schema validation, which forces the model to fill in every parameter, including ones you declared optional. To opt a tool into strict validation, declare `provider_options strict: true` on the tool class and make sure its schema meets the [strict mode requirements](https://platform.openai.com/docs/guides/function-calling#strict-mode) (every property in `required`, optional parameters expressed as nullable types).

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

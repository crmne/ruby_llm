---
layout: default
title: Upgrading
nav_order: 4
description: Move from RubyLLM 1.16 to 2.0, update your Ruby code, and migrate your Rails data.
redirect_from:
  - /upgrading-to-1-7
  - /upgrading-to-1-7/
---

# Upgrade to 2.0

{{ page.description }}
{: .fs-6 .fw-300 }

After reading this guide, you will know:

* Which API names and behaviors changed, and why.
* How to migrate your Rails records in phases.
* What each phase preserves and what cleanup removes.
* How to recover if you need to abandon the upgrade.

This guide covers **1.16 to 2.0.0.rc2**. Coming from an earlier release? Follow the [1.16 upgrade guide](https://rubyllm.com/upgrading/) first.

For a tour of the new features with examples, see [What's New in 2.0]({% link _getting_started/whats-new-in-2-0.md %}).

The upgrade has two parts: update your Ruby code and, if you use Rails persistence, migrate your stored records. Plain Ruby applications can skip the database steps.

## What Changes for Your App

2.0 adds tool approvals, more AI operations, and persisted batches, and tracks usage for each provider attempt. Two changes account for most of the upgrade work:

* **One name for each concept.** Tokens live under `tokens`, provider-specific options use `provider_options`, and callbacks follow the Rails-style `before_` and `after_` names.
* **RubyLLM maintains its supporting records.** The model registry, tool calls, usage entries, and batches belong to RubyLLM. You no longer need to maintain application models for them as the framework adds features. Your application keeps its chats and messages, with their existing IDs and relationships.

The usage ledger records tokens and costs for each provider attempt, including retries. The migration copies the usage you already have into that ledger; it cannot recover retry details or prices that 1.16 never stored.

## How to Upgrade

Update the gem in your development branch:

```bash
bundle add ruby_llm --version 2.0.0.rc2
```

Use the [API changes](#api-changes) below to update your calls, then run your tests. If you use Rails persistence, follow the steps below before deploying.

### 1. Generate the Rails Migrations

Choose how much migration work you want to do before pausing AI activity. The default `rename` mode moves the existing model and tool-call tables into RubyLLM's ownership. The optional `copy` mode prepares and backfills while 1.16 remains active, then catches up intervening writes during finish. It also retains a protected path back to 1.16.

| | Rename, the default | Copy, with `--mode copy` |
| --- | --- | --- |
| Existing model and tool-call tables | Renamed for 2.0. | Copied into the 2.0 tables; originals retained. |
| AI maintenance window | Prepare, backfill, and finish. | Finish and the application version switch. Prepare and backfill can run with 1.16 active. |
| Return to 1.16 | Restore the database backup and matching application together. | Run the rollback task and deploy the prepared 1.16 build. Conversations changed by 2.0 stay protected. |
| Extra work | Rehearse migration and backup recovery. | Also prepare the compatibility files, rehearse version switches, and allow storage and time for the copies. |

Generate the default rename migration:

```bash
bin/rails generate ruby_llm:upgrade
```

Or choose copy mode:

```bash
bin/rails generate ruby_llm:upgrade --mode copy
```

Copy mode needs compatibility files in both application versions. Conversations written by 2.0 are hidden from 1.16 until you return to 2.0. Read [Copy Mode](#copy-mode) before choosing it.

The generator creates three migrations. Cleanup is a separate migration you generate later:

| Phase | What it does | What happens to the old data |
| --- | --- | --- |
| Prepare | Adds the 2.0 schema. Rename mode moves supporting tables; copy mode creates separate targets and a change journal. | Copy mode leaves the legacy tables, references, and message content in place. |
| Backfill | Copies message content, tool-result links, and historical usage into the 2.0 format. | Keeps the legacy message columns. |
| Finish | In copy mode, stops guarded 1.16 writes and catches up the journal. Validates the data, completes constraints, and activates 2.0. | Keeps the legacy message columns. |
| Cleanup, later | Drops the legacy columns and progress table. In copy mode, also drops the original model and tool-call tables. | Removes the old copies after you have checked the upgrade. |

**Rename requires AI activity to remain paused through all three phases. Copy requires a pause before finish.** Install the generated compatibility files in every running 1.16 process before online preparation. Online copy supports PostgreSQL, MySQL, and SQLite; it does not mean lock-free operation. Schema changes can block writes. SQLite has one writer at a time, so application writes also wait for backfill batches. Rehearse with your database settings and workload. Run copy migrations and version switches through a direct database connection or a session-mode pool: their advisory locks do not support transaction-mode connection pooling.
{: .important }

The generator expects the schema produced by 1.16. If your models have different names, pass their mappings:

```bash
bin/rails generate ruby_llm:upgrade \
  chat:AI::Chat \
  message:AI::Chat::Message \
  model:AI::LLMModel \
  tool_call:AI::Chat::ToolCall
```

It prints the resolved classes and tables. Use the same mappings and `--mode` whenever you generate another phase.

### 2. Update Your Rails Models

Keep your application's chat and message models:

```ruby
class Chat < ApplicationRecord
  acts_as_chat
end

class Message < ApplicationRecord
  acts_as_message
end
```

Keep their application associations, validations, and other behavior. For custom associations, `acts_as_chat` accepts `messages:`, `message_class:`, and `messages_foreign_key:`. `acts_as_message` accepts `chat:`, `chat_class:`, `chat_foreign_key:`, and `touch_chat:`. Remove the old `model:` and `tool_calls:` options.

In your 2.0 application, remove the application `Model` and `ToolCall` classes and their `acts_as_model` / `acts_as_tool_call` declarations. The migrations rename or copy their tables; **do not drop those tables yourself**. Read the records through `RubyLLM.models`, `message.tool_calls`, `message.tokens`, and `chat.cost`. A 1.16 rollback build still needs its original classes and declarations.

Remove `config.model_registry_class` and `config.use_new_acts_as` from your initializer. Their compatibility setters let the generator boot, but do not enable the old APIs. If you still use `use_new_acts_as = false`, switch to the association-based API while on 1.16 first.

If you generated the chat UI, update its model picker to use `RubyLLM.models`. Iterate tool calls with `message.tool_calls.each_value`; persisted records are available through `message.ruby_llm_tool_calls`. Use an explicit HTML ID for internal tool-call records instead of Rails' `dom_id`. You can regenerate the UI with `bin/rails generate ruby_llm:chat_ui --force`, but review the files it overwrites.

### 3. Try the Upgrade on a Database Copy

Use a recent production database copy and the application version you plan to deploy. Run the migrations and your tests there first.

Check that you can read existing conversations, attachments, and tool results. Compare message counts, tool-result links, token counts, and any stored costs before and after. Measure how long the migrations take so you can plan the production pause. Preparation also builds indexes and may convert column types, so include it in the timing.

If your app added its own model settings or accounting, review [application-specific data](#application-specific-data) before proceeding.

For copy mode, also rehearse rollback and resume with both application builds. Include any custom message writes, background jobs, and attachment handling in that check.

### 4. Run the Upgrade

Take a database backup you have tested restoring. For rename, finish or cancel conversations waiting for tool results, then stop affected web requests, workers, scheduled jobs, and retries before any migration runs.

With the 2.0 application code ready and affected activity still paused, run:

```bash
bin/rails db:migrate
bin/rails ruby_llm:load_models
```

`load_models` loads the packaged registry without a network request. You can fetch newer metadata with `RubyLLM.models.refresh` later.

Check the converted records as you did in rehearsal, including any application-specific migrations. Then restart your processes and resume traffic.

For online copy, use this deployment order:

1. Deploy the generated concern and initializer with 1.16. Restart every affected process before changing the schema. These files make queries enumerate columns and guard version switches.
2. Run the prepare and backfill migrations from the 2.0 build while the prepared 1.16 build continues serving traffic. Keep the 2.0 web processes and workers stopped.
3. Pause AI requests and jobs, drain in-flight work, and finish or cancel pending tool calls, approvals, and batches. Run finish from the 2.0 build. It catches up changes made since backfill, validates the converted data, and activates 2.0.
4. Complete your application-specific conversions, load models, and restart on 2.0 before reopening AI activity.

To stop after backfill, use `bin/rails db:migrate VERSION=<backfill_timestamp>`. A plain `db:migrate` runs every pending migration, including finish. If you run all three in one release step, pause AI before that step; you do not get an online backfill window that way.

### 5. Clean Up in a Later Deployment

Once you have verified the upgrade in production, generate cleanup with the same model mappings:

```bash
bin/rails generate ruby_llm:upgrade --phase cleanup
```

In copy mode, first stop affected traffic and workers and close the rollback window from the 2.0 application:

```bash
bin/rails ruby_llm:upgrade:finalize
bin/rails generate ruby_llm:upgrade --mode copy --phase cleanup
```

Review the migration and run `bin/rails db:migrate` in a later deployment. Cleanup requires a successful finish phase. It drops the old message model and tool-call references, `content_raw`, token and supported cost columns, and the backfill progress table.

Cleanup also removes standalone indexes on the message `role` column in both modes. It preserves the chat index and composite indexes that include `role`.

Copy-mode cleanup also removes the change journal, old chat model reference, conversation version marker, and original model and tool-call tables. It promotes the shadow message content column to `content`. Move any application-owned references to the old tables first. Keep affected processes stopped through cleanup, remove the generated `ruby_llm_upgrade.rb` concern and initializer, and restart them. A small finalized-state record remains so an old build with the compatibility code cannot resume writing.

This removes the old copies, not the messages or usage already migrated to 2.0. Copy any application-specific data you still need before running it. New 2.0 writes do not update those legacy columns.

### Large Databases and Deployment Timeouts

You can generate the phases separately to control when they run:

```bash
bin/rails generate ruby_llm:upgrade --phase prepare
bin/rails generate ruby_llm:upgrade --phase backfill
bin/rails generate ruby_llm:upgrade --phase finish
```

Add `--mode copy` to each command if you chose copy mode.

Both modes process 10,000 messages per batch and save progress with each committed batch. If a backfill stops, repair the reported problem and rerun the migration. Completed batches are skipped and historical usage is not duplicated.

Copy mode also records source changes in a durable database journal. Its catch-up refreshes only affected conversations still owned by 1.16. Retrying the backfill is safe; finish always performs another catch-up while AI activity is paused, so you do not need a second backfill migration to include newer chats. Rails skips migrations it already recorded as successful. Provider tool-call IDs stay the same, but copied records have their own database IDs.

`db:migrate` runs every pending migration, even when you generated them separately. If your deployment's migration step has a timeout, make the new application version available under maintenance and run the phases with `bin/rails db:migrate:up VERSION=...`, in timestamp order, from a process without that timeout. Disable automatic migration runs during this operation and restore them afterward. Run only one backfill at a time.

### Recovery and Rollback

The migrations do not provide a `down` path. Retrying a failed phase is supported. Copy mode also has explicit [rollback and resume tasks](#copy-mode); changing the gem version alone does not switch the database back.

To abandon a rename-mode upgrade, restore the pre-upgrade database and the matching 1.16 application version together. A failed phase may have committed changes already. Restoring a backup also removes writes made after that backup, including unrelated application writes if you restore the whole database. Include that in your recovery plan.

### Copy Mode

Use copy mode when you want to test 2.0 in your application while keeping an option to return to 1.16. You can resume 2.0 after addressing a problem, then remove the retained data once you are ready to stay on 2.0. Rehearse this with your application's writes before relying on it.

Copy mode keeps the old model and tool-call tables, the chat's old model reference, and the legacy message content alongside their 2.0 replacements. It uses extra storage for these copies and the change journal. Backfill and catch-up update the derived format; 2.0 writes are not copied back into the legacy format.

The generator adds `app/models/concerns/ruby_llm_upgrade.rb` and `config/initializers/ruby_llm_upgrade.rb`. The initializer installs the compatibility behavior automatically. Deploy both files to the running 1.16 build before preparation, and include them in the 2.0 application. Keep the original 1.16 model classes and declarations in the legacy build. Before cleanup, the 2.0 message model aliases `content` to the shadow `ruby_llm_content` column; review custom SQL that reads content directly.

When 2.0 writes to a conversation, the compatibility code marks the whole conversation as version 2. During rollback, 1.16 hides those conversations and prevents ordinary record writes to them. Their records remain in the database and become available again when you resume 2.0. Other conversations remain usable in 1.16.

The compatibility code guards Active Record saves, updates, and destroys. Operations that bypass callbacks, including `update_columns`, bulk SQL, direct deletes, and attachment purges, are unsupported during this window. Review custom persistence code before choosing copy mode.

The guards coordinate record writes with version switches through short database locks and protect conversation ownership. Records loaded before a version switch cannot later save stale changes; fetch fresh records after a switch. The guard does not wrap provider requests or undo tool side effects, so you still need to drain in-flight work.

Before switching versions, finish pending tool calls and approvals, and finish or cancel pending batches. To return to 1.16, stop affected traffic and workers, then run this command **from the 2.0 application**:

```bash
bin/rails ruby_llm:upgrade:rollback
```

Deploy the prepared 1.16 build before restarting traffic and workers. The compatibility state selects one active version for the database. Running 2.0 for a percentage of customers while 1.16 serves the rest would need a separate deployment and data-isolation design outside this migration's scope.

To return to 2.0, stop affected traffic and workers again and run this command from the 2.0 application:

```bash
bin/rails ruby_llm:upgrade:resume
```

Resume copies the changes made while 1.16 was active into the 2.0 format and restores access to the protected conversations. You do not rerun the initial migrations. Restart traffic only after the task succeeds. These tasks do not restart provider jobs or undo external actions already performed by tools.

Once you decide to stay on 2.0, finalize the upgrade and run [cleanup](#5-clean-up-in-a-later-deployment). Finalization closes the rollback window.

## Application-Specific Data

Most applications can use the generated migrations as they are. These extra steps apply if you added your own data or behavior to RubyLLM's supporting records.

### Application Data on Model Records

In rename mode, extra columns on your old model table survive the rename, but RubyLLM does not maintain them. In copy mode, review the retained source table before cleanup removes it. Move your availability settings, pricing overrides, or other application data to a table you own, keyed by provider and model ID. Copy and verify the values before removing them from either table.

If your settings need to follow catalog changes, sync them after `RubyLLM.models.refresh`. See [Model Registry]({% link _reference/models.md %}).

### Your Own Usage Ledger

RubyLLM's ledger tracks provider usage. Keep your own ledger if it also handles customer billing, credits, quotas, or adjustments. You can read RubyLLM's costs through associations:

```ruby
class User < ApplicationRecord
  has_many :chats
  has_many :ruby_llm_usages, through: :chats
end

user.ruby_llm_usages.sum(:total_cost)
```

If you replace an existing usage table, compare the totals first and move any callbacks or UI updates that depend on it. Check application-owned foreign keys, logs, and evaluations that refer to the renamed model and tool-call tables too.

1.16 did not store costs by default. The backfill preserves `total_cost` and supported `cost_details` fields when present; otherwise historical costs stay unknown. It creates one succeeded usage entry per historical assistant response or other message with recorded usage. If a candidate has no identifiable model, preparation stops and names the record to repair.

### Existing Message Content

The backfill preserves 1.16's content precedence: a non-empty `content_raw` value becomes JSON text, otherwise the original text remains. It also copies `content_raw` into `raw_content`. Copy mode writes the text to `ruby_llm_content` and leaves the legacy columns unchanged until cleanup. If your app stored a custom format, check those rows and adapt your readers before cleanup. Keep tests for older formats that remain in your database.

## Updating an Earlier 2.0 Preview

If you already ran the Rails migrations from an earlier 2.0 preview, check these columns before deploying:

| Table | Required change |
| --- | --- |
| `ruby_llm_usages` | Require a model with `change_column_null :ruby_llm_usages, :model, false` if the column currently allows `NULL`. |
| `ruby_llm_tool_calls` | Add boolean `remote` with `default: false, null: false`. If your preview has `server` or `server_label`, set `remote` to `true` on rows with a label before removing that column. Use `tool_call.remote?` in application code. |
| `ruby_llm_batches` | Add nullable `reported_cost` for the provider's batch invoice, using `jsonb` on PostgreSQL or `json` on SQLite and MySQL. |

Add an application migration for any changes your schema needs. The current install and 1.16 upgrade generators include these columns. Read all batch pricing through `batch.cost`; its total stays `nil` until processing ends.

The model constraint stops the migration if any usage rows have `model: nil`. Recover their model IDs from the original requests before retrying. The migration does not assign a default model or delete usage records.

The preview APIs `RubyLLM.realtime` and `chat.with_storage` have been removed. Chats use local message history. Streaming [speech generation]({% link _core_features/text-to-speech.md %}) and [transcription]({% link _core_features/audio-transcription.md %}) remain available. Features that require provider-stored conversations are outside this release's scope.

## API Changes

Use this as your search-and-replace reference. Only change the calls your app uses. Changes to behavior are explained afterward.

| Before | Now |
|---|---|
| `response.content` returning a Hash for structured output | `response.parsed` - `content` is the JSON string |
| `RubyLLM::Content`, raw content blocks | String `content` plus `message.attachments`; `before_request` hook |
| `tool.call({ city: "Berlin" })` | `tool.call(city: "Berlin")` |
| `RubyLLM::Schema` | `Schematist::Schema` |
| Tool `halt("done")`, `RubyLLM::Tool::Halt` | Caller-controlled loop or tool approvals; see [tool execution](#tools-no-longer-halt-the-loop) |
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
| Application `Model.refresh!` | `RubyLLM.models.refresh` |
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
| Tool `desc` / `param` / `params`, parameter `desc:` | `description` / `parameter` / `parameters`, parameter `description:` |
| Tool `provider_params` and `params_schema` readers | `provider_options` and `parameters_schema` |
| `response.model_id`, `image.model_id` | `response.model`, `image.model` |
| `Error.new(response, "msg")` | `Error.new("msg", response: response)` |
| `with_tool(Weather)` | `with_tools(Weather)` |
| `with_tools(W, choice: :required, calls: :one)` | `with_tools(W).with_tool_options(choice: :required, calls: :one)` |
| `create_user_message(content)` | `ask_later(content)` returns the chat; `add_message(role: :user, content:, attachments:)` returns the message |
| `with_params(...)`, `params:`, tool `with_params` | `with_provider_options(...)`, `provider_options:` |
| `transcribe(audio, response_format: "srt")` | `transcribe(audio, format: "srt")` |
| `Moderation#results` raw hashes | Typed `Moderation::Result` objects |
| `Moderation#categories` | `moderation.flagged_categories`, or categories on each typed result |
| `Moderation#content`, `Image#usage`, Tool `#parameters` reader | `Moderation#results`, `image.tokens` / `image.cost`, no public reader |
| Bare `Agent.instructions` requiring its conventional prompt | Named agents load it automatically when present; use `instructions { prompt("instructions") }` to require it |
| `attachment.save(path)` | `File.binwrite(path, attachment.content)` for local or inline attachments |
| Temperature rewritten to `1.0` or dropped for some models | The temperature you set is the temperature sent |

## Behavior Changes

### Message Content and Structured Output

`Message#content` is read-only and returns text as a String, or `nil` when there is no text. Attachments live on `message.attachments`. Structured output responses carry the JSON text in `content`; read the parsed Hash through `Message#parsed`:

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

Backfill copies `content_raw` into `raw_content`; the later cleanup phase removes the old column. Tool results that return a Hash or Array now serialize as JSON text in the message content (previously Ruby `inspect` output).

### Token Readers

Read counts through `response.tokens` or `message.tokens`, including in Rails. The message columns are copied to the usage ledger during backfill and removed only during cleanup.

Token names use `thinking`, `cache_read`, and `cache_write`. Replace `tokens.reasoning`, `tokens.cached`, and `tokens.cache_creation` accordingly, including keywords passed to `RubyLLM::Tokens.new`.

`RubyLLM::Tokens.build` used to return `nil` when all counts were `nil`. If your app depends on that behavior, keep the check when switching to the constructor:

```ruby
counts.values.all?(&:nil?) ? nil : RubyLLM::Tokens.new(**counts)
```

`Cost` exposes amounts: `input`, `output`, `cache_read`, `cache_write`, `thinking`, `total`, and `to_h`. Read tokens and model identity from the result that owns the cost.

### Tool Result Messages

`Message#tool_results` changed meaning. It used to return a tool-result message's own content; it now returns the tool-result messages answering an assistant message's tool calls (an empty array when it made none), mirroring the `tool_results` association on `acts_as_message` records. Read a tool result's text with `message.content`.

### Chat Callbacks

The new `before_` and `after_` callbacks are additive: you can register more than one, and they run alongside RubyLLM's persistence callbacks. The old `on_*` callbacks replaced one another.

### Instructions Replace by Default

`with_instructions(replace:)` was removed. `with_instructions` replaces by default; pass `append: true` to add without replacing:

```ruby
chat.with_instructions("...", replace: true)   # before
chat.with_instructions("...")                  # now - replaces by default
chat.with_instructions("...", append: true)    # add another system message
```

### Agent Schema Blocks

A `schema do ... end` block declares a [Schematist schema]({% link _core_features/structured-output.md %}). For a schema computed from the agent's inputs, pass a lambda:

```ruby
schema do                                            # Schema DSL - static shape
  string :answer
end

schema -> { strict ? StrictSchema : LooseSchema }    # dynamic - evaluated per run
```

### RubyLLM::Schema Is Now Schematist

The schema DSL now lives in `schematist`, which RubyLLM installs as a dependency. Update your schema superclass:

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

The `cache_read` and `cache_write` names also apply to costs and pricing. Replace `cached_input*` and `cache_creation*` readers with `cache_read*` and `cache_write*`, such as `cost.cache_write` or `tier.cache_read_input_per_million`.

### Model Metadata and Pricing

Use `RubyLLM::Model` for model metadata, including entries returned by `RubyLLM.models`. Query tool-steering capabilities with `model.supports?(:tool_choice)` and `model.supports?(:parallel_tool_calls)` instead of provider predicates.

Pricing objects are read-only. Use named readers such as `pricing_category.standard`, `pricing_category.batch`, and `pricing_tier.input_per_million`. To change a price, update the registry data used to build the model instead of assigning through a pricing object.

### Error Constructors

Errors take the message first, like `StandardError`, and accept the response as a keyword: `RateLimitError.new("slow down", response: response)`.

`UnsupportedAttachmentError` now inherits from `RubyLLM::Error`, so `rescue RubyLLM::Error` catches it. Malformed tool-call JSON raises `RubyLLM::ToolCallParseError` instead of `JSON::ParserError`.

### Protocol Selection

`RubyLLM.chat`, `with_model`, and the agent `model` macro accept `protocol:` alongside `provider:`. Omitting it selects the provider's default for that model. Calling `with_model` without a protocol resets any previous override. See [Choosing the Wire Protocol]({% link _core_features/chat-request-control.md %}#choosing-the-wire-protocol).

### Tool Registration and Options

`with_tools` accepts one or many tools. Configure `choice:`, `calls:`, and `concurrency:` separately with `with_tool_options`.

To replace the current set, clear it first:

```ruby
chat.with_tools(nil).with_tools(Search, Calculator)
```

Passing `nil` to an option on `with_tool_options` resets it. On agents, use the `tools` macro for the tool set and `tool_options` for execution settings.

### Tools No Longer Halt the Loop

The caller now controls when the loop stops. Replace `halt` inside a tool with caller-side loop control:

```ruby
loop do
  chat.step
  break if chat.complete? || chat.awaiting_approval? || done_condition
end
```

For human approval, use [`requires_approval`]({% link _core_features/tool-execution.md %}#requiring-approval). For handing work to another agent, see [Agent Handoffs]({% link _advanced/agentic-workflows.md %}#agent-handoffs). A normal tool result does not stop the loop.

### Tool Provider Options Require a Hash

The tool class macro `provider_options` now requires a Hash. Passing `nil` raises instead of doing nothing.

### Zero Prices Mean Free

`model.pricing` used to drop 0.0 prices, making a free model indistinguishable from one with no pricing data. Zero now flows through as a real price (`cost.total` returns `0.0`); `nil` means the registry has no price.

### Model Registry Storage

A custom `model_registry_store` responds to `read` and, optionally, `write(registry)`. Rails configures its database store automatically. For a file fallback, set `model_registry_file`; its default is now a per-user OS cache path.

`RubyLLM.models.refresh` downloads the published registry, merges models discovered from your configured providers, and saves the result. If the download fails, it raises `RubyLLM::ModelRegistryError` and leaves the registry unchanged. The provider-only rebuild is available as `refresh_from_providers` for registry maintainers. See [Model Registry]({% link _reference/models.md %}).

### Agent Prompt Convention

In 1.16, calling the bare `instructions` class macro made an agent require its conventional `instructions.txt.erb` prompt. In 2.0, a named agent loads that prompt automatically when it exists, while bare `instructions` is only the reader for the configured value. Require the file explicitly when a missing prompt should fail:

```ruby
class WorkAssistant < RubyLLM::Agent
  instructions { prompt("instructions") }
end
```

### Provider-Specific Options

Use `provider_options` for options specific to a provider, on chat instances, agent and tool classes, and media calls:

```ruby
chat.with_provider_options(service_tier: "flex")
```

These values pass through in the provider's request format. RubyLLM no longer moves or rewrites provider-specific fields. Check the nesting of existing options against that provider's documentation. For example, Amazon Nova's `top_k` belongs under `additionalModelRequestFields: { inferenceConfig: { topK: ... } }`.

For instrumentation subscribers, the event payload key `:params` is now `:provider_options`.

### Transcription and Embedding Options

`RubyLLM.transcribe` uses `format:` instead of `response_format:`. It also accepts `speaker_names:` and `speaker_references:`; providers without speaker identification ignore them. Format values remain provider-specific, such as `"diarized_json"` on OpenAI or a MIME type on Gemini.

Use `timestamps:` to request timing information:

```ruby
RubyLLM.transcribe("talk.wav",
  model: "{{ site.models.transcription_openai_timestamps }}",
  timestamps: :word)
```

Available granularities depend on the model. See [Audio Transcription]({% link _core_features/audio-transcription.md %}#segments-and-timestamps).

For embeddings, `task_type:` and `title:` replace hand-built provider payloads such as Vertex AI's `instances:` array. See [Embeddings]({% link _core_features/embeddings.md %}).

### Temperature Handling

2.0 sends the temperature you set. 1.x sometimes changed it to `1.0` or removed it based on the model.

If you never set a temperature, nothing changes. If a model rejects your value, the provider now returns `RubyLLM::BadRequestError`. Remove `with_temperature` for those models to use their default.

### Typed Results

`Moderation#results` now returns `Moderation::Result` objects with `flagged?`, `categories`, and `category_scores`. Use `moderation.flagged_categories` for the combined flagged names, or inspect individual results.

Use `image.tokens` and `image.cost` for image usage. `Tool.parameters` declares a schema; it is no longer a public reader.

### Tool-Building Gems

Check that gems which build tools, such as ruby_llm-mcp, support the new tool API. They need the same `parameter`, `parameters`, and `provider_options` names as application tools.

## Providers and Protocols Split

RubyLLM 2.0 separates providers (authentication, endpoints, and catalog) from protocols (request and response formats). Two changes may affect your application:

**OpenAI now defaults to the Responses API.** The Responses API supports reasoning, tools, and extended thinking in the same request. To stay on Chat Completions:

```ruby
RubyLLM.configure do |config|
  config.openai_protocol = :chat_completions
end

# or per chat, as part of model selection
RubyLLM.chat(model: 'gpt-5.4', protocol: :chat_completions)
```

If you pass Chat Completions-only options via `with_provider_options` (like `response_format`), either switch those chats to `:chat_completions` or use the Responses API equivalents (`text: { format: ... }`).

RubyLLM sends `strict: false` for function tools to preserve optional parameters. To use strict validation, set `provider_options strict: true` on the tool class and follow the [strict mode requirements](https://platform.openai.com/docs/guides/function-calling#strict-mode).

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

## Older Upgrade Guides

Use the version selector or the [1.16 upgrade guide](https://rubyllm.com/upgrading/) for older releases. Upgrade one minor version at a time and resolve its deprecation warnings before continuing. See [GitHub releases](https://github.com/crmne/ruby_llm/releases) for the full changelog.

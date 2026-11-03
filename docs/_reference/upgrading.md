---
layout: default
title: Upgrading
nav_order: 4
description: Move a RubyLLM 2.1 application to 2.2, one release at a time.
redirect_from:
  - /upgrading-to-1-7
  - /upgrading-to-1-7/
---

# Upgrade to 2.2

{{ page.description }}
{: .fs-6 .fw-300 }

After reading this guide, you will know:

* How RubyLLM upgrades move from one release to the next.
* How to upgrade a 2.1 application and its Rails schema to 2.2.
* How persisted chats now run in one process at a time.
* What changes for a crashed job, a denial, pending approvals, an MCP input error, a stdio server's environment, a dropped MCP tool call, a write over a folder, a document URL, and a deploy that mixes versions.
* What changes for agent `rescue_from` handlers and streamed transcription chunks.
* How `tool_calls` reads now that it is a collection of calls.
* Which errors failed Responses requests raise.
* Why Bedrock batches report no request counts.
* Which job predicates replace `done?` and `completed?`.
* Why agents name their chat record with `chat_class`.

This guide covers **2.1 to 2.2**. Coming from 2.0? Follow the [2.1 upgrade guide](https://github.com/crmne/ruby_llm/blob/v2.1.1/docs/_reference/upgrading.md) with RubyLLM 2.1 first.

## One Release at a Time

Each release ships the upgrade steps for the changes since the previous release. When a release changes the Rails schema, `bin/rails generate ruby_llm:upgrade` generates the migrations that take your database from the previous release to the current one. The next release replaces that generator with its own.

To move across several releases, upgrade to each one in turn. Deploy it, run its upgrade, and resolve its deprecation warnings before you continue. Each release's upgrade guide stays in the repository at that release's tag.

## Finish the 2.1 Upgrade

2.2 does not include the 2.1 upgrade generator. Run it while your application still runs 2.1, in every environment, and keep the migration it generated in `db/migrate`.

## Update the Gem

Require 2.2 in your `Gemfile`, so the update stops at this release:

```ruby
gem "ruby_llm", "~> 2.2.0"
```

Then update it in your development branch:

```bash
bundle update ruby_llm
```

Plain Ruby applications need no changes. Rails applications upgrade their schema and read the changes to persisted chats below.

## Upgrade the Rails Schema

Rails applications generate and run the 2.2 upgrade:

```bash
bin/rails generate ruby_llm:upgrade
bin/rails db:migrate
```

If your chat model is not `Chat`, name it the way you did for the install generator, for example `bin/rails generate ruby_llm:upgrade chat:Conversation`.

It adds `claim_token` and `claimed_until` columns to your chats table and a `claimed_until` column to `ruby_llm_tool_calls`. They record which process runs a chat and its tool calls. It also adds a nullable `provider_call_id` column to tool calls so RubyLLM can distinguish invocations when a provider reuses an ID, a nullable `phase` column to your messages table, which keeps the label OpenAI's Responses API gives each answer so later requests send it back, a nullable `continuation` text column to your messages table, which keeps the token an unfinished [long response]({% link _core_features/chat.md %}#long-responses) resumes from, and creates the `ruby_llm_queued_messages` table, which holds [queued messages]({% link _advanced/rails-persistence.md %}#queued-messages) until a chat takes them, and the `ruby_llm_chat_files` table, which holds the [files]({% link _core_features/chat-files.md %}#files-in-rails) of chats that use `with_file_store`. It adds nullable `workflow_id`, `workflow_name`, `workflow_step_id`, and `workflow_step_name` columns to `ruby_llm_usages`, which record the workflow each attempt ran in (see [Usage Rows Record Their Workflow](#usage-rows-record-their-workflow)). On MySQL, it widens the `content`, `thinking_text`, and `thinking_signature` columns of your messages table and the `thought_signature` column of `ruby_llm_tool_calls` to long text, so replies over 64 KB fit, and creates queued message `content` as long text. MySQL rebuilds each of those two tables once to change the column types, which blocks writes to it while it runs, so run the migration when a large messages table can pause. Other databases need no change. The migration changes no existing data. The generator also creates any of RubyLLM's conventional directories your application lacks, such as `app/skills` and `app/sandboxes`, and an `app/agents/application_agent.rb` that points at your chat model, unless you already have one. New agents from `ruby_llm:agent` inherit from it.

The generator also removes the broadcasting code and the `has_many_attached :attachments` line that `ruby_llm:chat_ui` wrote into your message model, because `acts_as_message` now provides both, and turns on `config.broadcast_messages` when it removes that broadcasting code. It installs Active Storage if your application lacks it. Broadcasting code you wrote yourself stays untouched.

A chat UI generated by 2.1 still uses that broadcasting code: its job calls `broadcast_append_chunk` and its page subscribes to the stream the model names. While your application has either, the generator leaves the message model and `config.broadcast_messages` alone, and the chat UI keeps working as it did. Rerun `ruby_llm:chat_ui` to move the job, the views and the model to RubyLLM's broadcasting together. The 2.2 chat UI also queues messages sent while a reply runs instead of refusing them.

Run the migration before deploying 2.2.

The upgrade also adds a nullable `namespace` column to `ruby_llm_tool_calls`, which keeps the [tool namespace]({% link _core_features/tools.md %}#tool-namespaces) of each call, such as a member of a [native client toolset]({% link _core_features/provider-tools.md %}#native-client-toolsets). Existing calls have no namespace. Remembered approvals apply to tools with the same namespace and name.

If you already ran an unreleased 2.2 upgrade without this column, add it in a new migration before updating:

```ruby
add_column :ruby_llm_tool_calls, :namespace, :string
```

If you already ran an unreleased 2.2 migration that created `provider_id` on `ruby_llm_tool_calls`, rename that column in a new migration before updating:

```ruby
rename_column :ruby_llm_tool_calls, :provider_id, :provider_call_id
```

## Batches Take One Set of Credentials

`RubyLLM.batch` used to send every chat with the first chat's credentials, even when chats came from contexts with different API keys. It now raises `ArgumentError`. Submit one batch per tenant.

## Tool Call IDs Belong to RubyLLM

New tool calls receive a RubyLLM ID rather than exposing the provider's ID. Continue using `tool_call.id` for callbacks, approvals and results. Do not compare it with an ID in a raw provider response. Existing persisted calls keep their IDs, and newly persisted calls keep theirs across reloads and job retries.

Restart every worker on 2.2 before resuming these conversations. A 2.1 worker does not read the saved provider ID.

Each new invocation has its own ID, even when a provider repeats an earlier ID or requests the same arguments again. A one-time approval applies only to that invocation. `remember: true` continues to approve later calls to the same tool, except on a call that already has a result, which now remembers nothing.

For chats with tool calls saved before 2.2, batch redelivery checks still rely on those older provider IDs. Start a new chat for new batches if your provider reuses them.

## Messages Can Broadcast With Turbo

An application that broadcasts its messages itself needs no change: RubyLLM's broadcasting is off unless you turn it on.

```ruby
RubyLLM.configure do |config|
  config.broadcast_messages = true
end
```

With it on, and turbo-rails and Action Cable loaded, `acts_as_message` broadcasts a chat's messages to the chat record's stream, `turbo_stream_from @chat`. It appends an empty assistant reply when it is created, replaces a message when it is saved, removes it when it is destroyed, and refreshes the chat's page after every change and at the end of each run. Streamed chunks know their record, so a job streams with `chat.complete(&:broadcast)`. See [Streaming with Hotwire/Turbo]({% link _advanced/rails-streaming.md %}).

Broadcasting renders each message with its partial, chosen by `to_partial_path`, so an application that turns it on needs `messages/_user`, `messages/_assistant`, `messages/_tool`, and `messages/_tool_calls`. A model's `broadcasts:` option overrides the configuration.

## Usage Rows Record Their Workflow

Usage rows written inside `RubyLLM.workflow` store the workflow and step, so you can total the cost of a piece of work, including guardrails, embeddings, and other calls outside its chat:

```ruby
RubyLLM.workflow("Support reply", id: "chat-#{chat.id}") do |workflow|
  workflow.step("Retrieve") { RubyLLM.embed(question) }
  workflow.step("Answer") { chat.ask(question) }
end

RubyLLM::ActiveRecord::Usage.where(workflow_id: "chat-#{chat.id}").sum(:total_cost)
```

Rows written before the upgrade have no workflow. Until you run the migration, RubyLLM writes rows without one. See [Usage by Workflow]({% link _core_features/cost-and-usage-tracking.md %}#usage-by-workflow).

## Usage Rows Record Characters, Audio Seconds, and Search Units

`Tokens` now counts the units some operations bill instead of tokens: `characters` for text-to-speech, `audio_seconds` for transcription billed by duration, and `search_units` for Cohere reranking. `Cost` prices them in components of the same names. Usage rows store them in new `characters`, `audio_seconds`, and `search_units` columns, with `characters_cost`, `audio_seconds_cost`, and `search_units_cost` beside them:

```ruby
RubyLLM::ActiveRecord::Usage.where(operation: "speech").sum(:characters)
```

Rows written before the upgrade have no units. Until you run the migration, RubyLLM writes rows without them. See [Characters, Audio Seconds, and Search Units]({% link _core_features/cost-and-usage-tracking.md %}#characters-audio-seconds-and-search-units).

## Messages Declare Their Attachments

`acts_as_message` now declares `has_many_attached :attachments`, so you can remove that line from your message model. Without Active Storage, the model boots without attachments and RubyLLM logs how to add them; storing an attachment then raises `RubyLLM::ConfigurationError`. To add Active Storage, run `bin/rails active_storage:install` and `bin/rails db:migrate`.

## The Default Model Is GPT-6.1 Sol

`RubyLLM.chat` without a model, and a persisted chat created without one, now use `gpt-6.1-sol` instead of `gpt-5.6`. To keep the previous model, set it in your configuration:

```ruby
RubyLLM.configure do |config|
  config.default_model = "gpt-5.6"
end
```

## One Process Runs a Chat

In 2.1, two processes that completed the same persisted chat at the same time could both run an approved tool call and both ask the model for a reply, for example when a double-submitted approval enqueued two jobs. In 2.2, `complete`, `step`, `generate`, `run_tools`, and `compact` claim the chat before they call the model or run a tool, and each tool call is claimed before it runs. A process that finds the chat claimed returns without doing anything:

* `complete` returns the latest message, and `step`, `generate`, and `compact` return `nil`.
* `waiting?` is `true`, so loops that stop on `complete? || waiting?` stop.
* `chat.running?` and a tool call record's `running?` are `true`.

The process that holds the claim continues with approvals and questions recorded while it ran. See [One Process at a Time]({% link _advanced/durable-agents.md %}#one-process-at-a-time).

## Crashed Runs Resume After Their Claim Expires

In 2.1, `complete` ran the unfinished tool calls of a crashed job right away. In 2.2, a crashed job keeps its claims for `config.max_run_time`, ten minutes by default, and `complete` in another process returns until they expire. A job retried within that time finds the chat `running?` and does nothing. Check `running?` after `complete` and enqueue the job again later, as [Resuming a Crashed Run]({% link _advanced/durable-agents.md %}#resuming-a-crashed-run) shows.

Give tools that legitimately run longer than ten minutes their own limit with [`max_run_time`]({% link _core_features/tools.md %}#long-running-tools), and raise `config.max_run_time` above your slowest model request without streaming. A run that outlasts its claim counts as crashed and may run again.

## Cancelled Chats Close Their Tool Calls

In 2.1, a cancelled chat left its unanswered tool calls open: `ask` raised `PendingToolCallsError` and `complete` ran them, which ran a tool a second time if the cancel arrived after it returned. A tool that returned now keeps its result, and `RubyLLM::CancelledError` closes every other pending call as unfinished, including calls waiting for approval or input, so the next `ask` goes on. Code that checks for pending calls after a cancel finds none.

## Empty Streams Raise

A streamed request whose response holds no events, such as an empty body or a plain JSON body from a gateway that ignores `stream: true`, returned a blank assistant message in 2.1. It now raises `RubyLLM::Error` and adds nothing to the transcript.

## Failed Responses Raise What They Report

A non-streaming Responses request that comes back `failed` now raises the same class a stream raises, such as `RubyLLM::RateLimitError`, in place of a plain `RubyLLM::Error`. A `failed` response with no error object raises `RubyLLM::Error` instead of returning an empty message. Embeddings with an error in a successful body raise a `RubyLLM::Error` subclass too. `rescue RubyLLM::Error` keeps working.

## Options a Provider Cannot Carry Raise

Operations used to drop these options silently. They now raise `ArgumentError` before any request, naming the option. Remove the option, or switch provider.

| Operation | Option | Raises on |
| --- | --- | --- |
| `upload` | `uri:` | Every provider except Vertex AI and Bedrock |
| `upload` | `purpose:` | Anthropic, Bedrock, ElevenLabs, Gemini, OpenRouter, Vertex AI |
| `upload` | `expires_in:` | Bedrock, Cohere, ElevenLabs, Gemini, OpenRouter, Vertex AI |
| `transcribe` | `format:` | Cohere, Deepgram, Mistral, xAI |
| `transcribe` | `prompt:` | Cohere, ElevenLabs, xAI |
| `transcribe` | `temperature:` | Deepgram, xAI |
| `transcribe` | `speaker_names:` | Cohere, Gemini `generateContent` models |
| `transcribe` | Non-empty `speaker_names:` (`[]` still requests labels) | Deepgram, Gemini and Vertex AI dedicated transcription, Mistral, xAI |
| `transcribe` | `speaker_references:` | Cohere, Deepgram, ElevenLabs, Gemini `generateContent` models, Mistral, xAI |
| `paint` | `count:` above 1 | ElevenLabs, OpenRouter, Stable Diffusion on Bedrock |
| `speak` | `format:` other than `"pcm"` | Gemini, Vertex AI |
| `embed` | `task_type:` | Azure, Mistral, OpenAI, Perplexity, GPUStack, Titan on Bedrock |
| `embed` | `title:` | Azure, Cohere, Mistral, OpenAI, OpenRouter, Perplexity, GPUStack, Bedrock |

`provider_options:` on `upload` now reach the provider on every path: the multipart form, the Gemini File resource, Bedrock's PutObject, and Vertex AI's `create_file`. A key the provider does not recognize gets its own error, or `ArgumentError` from the Bedrock and Vertex AI SDKs, instead of vanishing. The option `expires_in:` inside `provider_options:` is no longer translated, so pass it as the `expires_in:` keyword.

Three options now take effect instead. `expires_in:` on `upload` reaches Anthropic as `expires_in_seconds`. `content_type:` on `upload` reaches every provider. `size:` also reaches Imagen and OpenRouter, so a request that used to get a square image follows what you asked for. Imagen takes it as an aspect ratio, and a tier such as `"2K"` raises `ArgumentError`. OpenRouter takes ratios, tiers, and pixel dimensions.

A WAV file for streamed transcription whose odd final chunk has no pad byte is now accepted.

## Chat Options a Provider Cannot Carry Raise

These chat options were dropped, or downgraded with a log line. They now raise when the request is built.

| Option | Raises on | Do instead |
| --- | --- | --- |
| `with_schema` | DeepSeek Chat Completions | Pass `protocol: :responses` |
| `with_thinking(budget:)` | DeepSeek, Mistral, Ollama | Use `effort:` |
| `with_thinking(effort: :high, display: :full)` | Gemini | Use `display: :summarized` or `display: :omitted` |
| `with_tool_options(choice: :none)` with tools | Bedrock Converse | Remove the tools |
| `with_tool_options(calls: :one)` | Mistral Conversations | Use Chat Completions |
| `with_caching(id:)` | Gemini Interactions | Use the default protocol |
| `with_caching(ttl:)` or `with_caching(id:)` | Cohere | Use bare `with_caching`; Cohere caches on its own |
| System attachments | Gemini Interactions | Attach to a user message |

`with_thinking(display: :omitted)` on Gemini now takes effect and keeps thoughts out of the response.

## Bedrock Batches Report No Request Counts

`Batch#request_counts` on Bedrock is now `nil`. It used to hold the job's submit and end timestamps under `submitted` and `completed`, which are not counts. Bedrock's job status reports no counts. A persisted batch keeps the old value until its next `refresh`.

## MCP Prompts Take No Attachments

`ask(prompt, with: file)` with an `MCP::Prompt` dropped the attachment in 2.1. It now raises `ArgumentError`.

## Stdio MCP Servers Get a Short Environment

A stdio MCP server inherited your application's whole environment in 2.1, including every API key. It now gets only `HOME`, `LOGNAME`, `PATH`, `SHELL`, `TERM`, `USER`, `TMPDIR`, `LANG`, `LC_ALL`, `LC_CTYPE`, `GEM_HOME`, `GEM_PATH`, their Windows equivalents, and what you set with `env`. A server that relied on anything else, such as a token, a proxy, `NODE_EXTRA_CA_CERTS`, or `BUNDLE_PATH`, now needs it passed explicitly:

```ruby
class Files < RubyLLM::MCP
  command "npx", "-y", "@modelcontextprotocol/server-filesystem", "."
  env NODE_EXTRA_CA_CERTS: ENV.fetch("NODE_EXTRA_CA_CERTS")
end
```

## Dropped MCP Tool Calls Are Sent Again Only When Idempotent

When a response stream from a 2026-07-28 server broke before the answer, 2.1 sent the tool call again, up to three times, so a tool with side effects could run four times. RubyLLM now sends a call again only when the server marks the tool `idempotent?` with the `idempotentHint` annotation. Any other tool call raises `RubyLLM::MCP::Error` after the first dropped stream, and the tool may or may not have run. Other requests, and resuming a stream on older servers, work as before.

## Gemini Returns Every Image It Made

`paint` kept the first image of each Gemini candidate in 2.1, and dropped the rest you were billed for. A response with several images now returns an Array of `Image`, as `count:` does, so check the class if a model can answer one prompt with more than one image. Draft images a model marks as thoughts stay out.

## Unreadable Batch Answers Fail Their Own Slot

One answer RubyLLM could not parse, such as a tool call cut off at the token limit, made `batch.messages` raise for the whole batch in 2.1. That answer now counts as failed in `batch.statuses` and the others arrive.

## Research Jobs Found Finished Report Usage

A `ResearchJob` found by ID after its task finished reported no usage in 2.1. In 2.2 it reports it once per `ResearchJob` object, like `Batch.find`. Finding the same finished task from two processes reports it twice, so collect each task in one place.

## Pricing Changes in `cost_for`

`model.cost_for(chat)` and `model.cost_for(message)` priced the summed tokens of every request, so several short requests could cross the long-context threshold together and all pay the long-context rate. In 2.2 each request pays the tier its own prompt reached.

`model.cost_for(tokens, tier: :batch)` priced at standard rates when the model had no batch price. In 2.2 those amounts and `total` are `nil`, the same as any other missing price.

A retry that recovered from an HTTP 5xx left `chat.cost.total` `nil`, because the failed attempt's usage was unknown. In 2.2 an attempt the provider answered with an error before streaming anything records zero tokens, so the total is known.

## Requests That Were Silently Dropped Now Raise or Report

* A Responses API request with a tool in the `computer` or `browser` namespace raises `RubyLLM::Error`. The API reserves those names and dropped the functions without an error. Rename the namespace.
* An Anthropic batch that ended with any successful request is `:succeeded`, with its cancelled requests failed in their own slots. In 2.1, one cancelled request made the whole batch `:cancelled`.
* A finish reason RubyLLM does not map is a lowercase Symbol on every provider. Gemini's `MALFORMED_FUNCTION_CALL` was `:MALFORMED_FUNCTION_CALL` and is now `:malformed_function_call`; Cohere's reasons change the same way.
* `Moderation#model` for a Bedrock guardrail returns the `"id:version"` its usage records, instead of `nil`.
* When an Anthropic server tool pauses a turn, `message.thinking` joins the thinking of every segment instead of keeping only the last.

## `search_files` Reads Only Extracted Text

In 2.1, the `search_files` tool ran your converters on every file it searched, so one search could send every uncached PDF and image through paid OCR. In 2.2 it searches text files and text already extracted, and lists the files it skipped. The model reads those with `read_file`, or your code extracts them first with `chat.file_store.text(path)`.

## Sonar Model Names No Longer Run Perplexity Presets

Perplexity retired Sonar on September 27, 2026. In 2.1, `sonar`, `sonar-pro`, `sonar-reasoning-pro`, and `sonar-deep-research` ran the presets Perplexity recommended in their place, with a deprecation warning. In 2.2 RubyLLM sends them as model names and Perplexity answers. Name the preset instead: `fast` for `sonar`, `low` for `sonar-pro`, `medium` for `sonar-reasoning-pro`, and `high` for `sonar-deep-research`.

```ruby
RubyLLM.chat(model: "fast", provider: :perplexity)
```

## Batches Picked Up by ID Report Usage

A batch collected through `Batch.find` without its chats or requests now reports its usage, to `usage.ruby_llm` and the ledger, once the batch is complete, once per `Batch` object. It reported nothing in 2.1. Collecting the same batch that way from two processes reports it twice, so collect each one in one place.

## `tool_calls` Is a Collection of Calls

`message.tool_calls` used to be a Hash keyed by call ID, or `nil` on a plain message without calls. It is now an Enumerable of `RubyLLM::ToolCall` objects, in the order the provider returned them, on plain messages, chunks, and persisted records alike:

```ruby
response.tool_calls.first
response.tool_calls.map(&:name)
response.tool_calls["call_1"]
```

`[]`, `fetch`, `values`, `keys`, `key?`, `each_key`, `each_value`, `transform_values`, and `size` work as before, and the collection equals an equivalent Hash. Other Hash methods, such as `dig`, `merge`, and `each_pair`, raise `NoMethodError`: call `to_h` first. `include?` now looks for a call, not an ID, so check an ID with `key?`. Two more things change.

Blocks receive a call, not an ID and a call. This covers `each` and everything Enumerable builds on it, such as `map`, `select`, and `any?`, and `select` and `reject` return Arrays. Take one block argument, or call `to_h` for the Hash:

```ruby
# Before
response.tool_calls.each { |id, call| puts "#{id}: #{call.name}" }

# After
response.tool_calls.each { |call| puts "#{call.id}: #{call.name}" }
```

An empty collection is truthy, so `if message.tool_calls` is now always true. Use `message.tool_call?`:

```ruby
# Before
run(message) if message.tool_calls

# After
run(message) if message.tool_call?
```

## Tool Results That Cannot Be Sent Reach the Model as Errors

A tool that returns an array mixing attachments with other values, such as `[attachment, 42]`, used to raise `ArgumentError` out of `ask`. The tool has already run by then, so raising left the call pending to run again. The model now receives `{ error: }` as the tool result and the chat continues, so a `rescue ArgumentError` around `ask` no longer sees this case. Return Strings and attachments from your tools.

## Writing Over a Folder Raises

`RubyLLM::FileStore::Directory#write` used to delete a folder at the path it was given, with everything in it. It now raises `ArgumentError` and leaves the folder alone. The `write_file` tool answers the model with the reason, and an attachment named like a folder gets a numbered name beside it. To replace a folder with a file, delete the folder yourself first.

## Same-Named Attachments Both Reach `run_code`

In 2.1, a later attachment overwrote an earlier one with the same name in `attachments/`. The newest still takes the name, and an older one is now `report-2.txt` beside it. Names are compared without case, so `Report.txt` and `report.txt` with different content get separate names on every filesystem.

## Rescue Denials of Running Calls

`deny` on a persisted tool call that has started running now raises `RubyLLM::ToolCallRunningError`; in 2.1 it recorded a denial the running tool never saw. `approve` on a running call and either decision on an answered call change nothing, where 2.1 overwrote the recorded decision. Rescue the error where you record denials:

```ruby
rescue_from RubyLLM::ToolCallRunningError do
  redirect_back fallback_location: root_path, alert: "That action is already running."
end
```

## Pending Approvals Read the Database

In 2.1, `pending_approvals` on a persisted chat built the chat's tools to find the calls that need a decision, which connected to every MCP server the chat uses, starting stdio servers in the web process. In 2.2, the process that saves a call records whether it waits for approval on the call's record, and `pending_approvals` reads only the database. The schema does not change, but the `approval` column of `ruby_llm_tool_calls` now holds `pending` for a call that waits for a decision, where 2.1 left it empty. If your code reads that column and treats an empty value as undecided, treat `pending` the same way:

```ruby
RubyLLM::ActiveRecord::ToolCall.where(approval: [nil, "pending"], result_id: nil)
```

Calls that were already waiting for approval when you deploy have no such record, so `pending_approvals` leaves them out. Load the chat through its agent class, so its tools and MCP servers are registered, list those calls the 2.1 way, which still connects to the chat's servers, and decide them by ID:

```ruby
chat = ChatAgent.find(chat_id)
chat.to_llm.pending_approvals.map(&:id) # => ["call_1a2b3c"]
chat.approve("call_1a2b3c")
```

## Agent Handlers Cover Every Chat

`rescue_from` handlers used to run only on `Agent.new`. They now also run on the chats and records from `Agent.chat`, `create`, `create!`, and `find`, and on calls chained from a setter such as `agent.with_temperature(0.2).ask("Hi")`. A generated `ChatResponseJob` starts running the handlers your agent declares, so a handler that returns instead of raising keeps that error from Active Job, which no longer retries it. Re-raise in the handler to keep the retry.

`rescue_from` now raises `ArgumentError` when you declare a class that can never match a `StandardError`, such as `Interrupt`. Agents rescue only `StandardError`s, so such a handler never ran: remove it. Handlers for `StandardError` classes, their ancestors such as `Exception`, and modules your error classes include work as before.

## Transcription Chunk Types Are Symbols

`TranscriptionChunk#type` is now `:delta`, `:partial`, `:segment`, or `:done` instead of a wire string such as `"transcript.text.delta"`, and `nil` for a provider event RubyLLM does not normalize. Replace literal comparisons:

```ruby
# Before
print chunk.delta if chunk.type == "transcript.text.delta"

# After
print chunk.delta if chunk.delta?
```

The predicates and constants such as `TranscriptionChunk::DELTA` keep working. `chunk.raw` still holds the provider's event.

## Jobs Use `complete?` and `succeeded?`

`VideoJob`, `ResearchJob`, `Task`, and `MCP::Task` now use the same two predicates as `Batch`: `complete?` means finished either way, and `succeeded?` means finished with a result. `done?` and `completed?` still work on those objects and warn through `RubyLLM.deprecator`. RubyLLM 3.0 removes them.

```ruby
# Before
job.done?
job.completed?

# After
job.complete?
job.succeeded?
```

A `ResearchJob` that stopped early is `complete?` and `incomplete?` but not `succeeded?`, and `message` still carries its partial report. Status values do not change, so `job.status` still returns `:completed`. `TranscriptionChunk#done?` also stays, because it means the end of a stream.

## Rescue Input Errors as Input Errors

Tools can now [ask the user]({% link _core_features/tools.md %}#asking-the-user) something, the way MCP servers do, so `RubyLLM::MCP::InputRequiredError` now inherits from the new `RubyLLM::InputRequiredError` instead of `RubyLLM::MCP::Error`. A `rescue RubyLLM::MCP::Error` no longer catches it. Rescue the general error, which also catches a tool's own unanswered questions:

```ruby
begin
  tool.call(**arguments)
rescue RubyLLM::InputRequiredError => e
  e.requests.each { |request| puts request.message }
end
```

`RubyLLM::MCP::InputRequest` is now `RubyLLM::InputRequest`, the same class under its old name.

## Providers Fetch Document URLs

In 2.1, RubyLLM downloaded every URL attachment and sent its bytes. In 2.2, PDF and Office document URLs sent through the Responses API on OpenAI, Azure, xAI, OpenRouter, and Meta go to the provider as URLs, and the provider downloads them. A URL that only your servers can reach, such as one on a private network or behind your application's login, worked in 2.1 and fails in 2.2. Attach the file as a local path, an IO, or an Active Storage attachment instead, so RubyLLM sends its bytes. See [Letting the Provider Fetch Document URLs]({% link _core_features/attachments.md %}#letting-the-provider-fetch-document-urls).

## Responses Keep No Request Headers

In 2.1, `message.raw` and `error.response` still carried the request headers, including the API key, and `error.response` also carried the request body, the whole serialized conversation. In 2.2 they keep neither, so logging or reporting them no longer leaks keys or prompts. To see what a chat sends, use `render` or a `before_request` hook, described in [Advanced Request Control]({% link _core_features/chat-request-control.md %}#request-hooks).

## A Malformed Response Raises RubyLLM::Error

In 2.1, a successful response with a body RubyLLM could not parse raised `Faraday::ParsingError`. In 2.2 it raises `RubyLLM::Error`, so `rescue RubyLLM::Error` catches it. Replace any `rescue Faraday::ParsingError` in your application.

## Network Failures Raise RubyLLM::ConnectionError

In 2.1, a request that timed out, could not connect, or failed TLS raised `Faraday::TimeoutError`, `Faraday::ConnectionFailed`, or `Faraday::SSLError`, which `rescue RubyLLM::Error` missed. In 2.2 RubyLLM retries it as before, then raises `RubyLLM::ConnectionError`, with the Faraday error as its `cause`. Replace those Faraday classes in your `rescue`, `rescue_from`, and `with_fallbacks(on:)` lists with `RubyLLM::ConnectionError`, and use `error.timeout?` to tell a timeout apart.

MCP servers and their authorization servers follow the same rule. In 2.1, an MCP request that could not reach its server raised a Faraday error, and `listen` raised `RubyLLM::MCP::Error`. An unreachable token endpoint raised `RubyLLM::MCP::Error` saying it refused the request, and a token refresh that could not connect counted as refused. In 2.2 each raises `RubyLLM::ConnectionError`. Rescue it next to `RubyLLM::MCP::Error` where you handle MCP failures. A custom transport should raise it too when its server can't be reached.

## Agents Say `chat_class`

Use `chat_class` to name your agent's chat record. `chat_model` read like an LLM, as in `RubyLLM.models.chat_models`, and `chat_class` is the name `acts_as_message` already uses. `chat_model` still works and warns through `RubyLLM.deprecator`. RubyLLM 3.0 removes it.

```ruby
class ApplicationAgent < RubyLLM::Agent
  chat_class Chat
end
```

## Rename Chat Columns Named After New Methods

`acts_as_chat` records gain `code_execution`, `skills`, `file_store`, `with_code_execution`, `with_skills`, `with_file_store`, `queue`, `queued_messages`, `unqueue`, `join_queued_messages`, `after_queue`, `around_join`, `after_join`, `after_unqueue`, `after_file_write`, and the `ruby_llm_chat_files` association in 2.2. A column of your own with one of those names is hidden behind RubyLLM's method, so reading it returns RubyLLM's setting, usually `nil`, instead of your value. Rename such a column before you upgrade, for example a `code_execution` toggle to `runs_code`:

```ruby
rename_column :chats, :code_execution, :runs_code
```

## Rename Protocol Method Overrides

Applications need no change. These are internal provider and protocol methods, but a provider gem or a custom provider that overrides one must rename its override, because RubyLLM no longer calls the old name. In 2.2 every method that builds part of a request starts with `render_`, every method that reads part of a response starts with `parse_`, and the two capability predicates drop `supports_`:

```ruby
# 2.1
def format_role(role)
  role.to_s
end

def extract_thinking_text(message_data)
  message_data["reasoning"]
end

def supports_provider_file_references?
  false
end

# 2.2
def render_role(role)
  role.to_s
end

def parse_thinking_text(message_data)
  message_data["reasoning"]
end

def provider_file_references?
  false
end
```

* `format_*` is now `render_*`. The ones providers override most are `format_role`, `format_content`, `format_message_content`, `format_image`, `format_document`, `format_video`, `format_thinking`, `format_tool_calls`, and `format_provider_file`.
* `extract_*` is now `parse_*`, for example `extract_usage`, `extract_thinking_text`, `extract_thinking_signature`, `extract_raw_reasoning`, and `extract_server_tool_use`.
* `supports_embedding_media?` is now `embedding_media?`, and `supports_provider_file_references?` is now `provider_file_references?`.

Calls to the shared modules change the same way, so `Protocols::ChatCompletions::Media.format_content` becomes `Protocols::ChatCompletions::Media.render_content`.

A few methods keep their names: `format_cache_option_keys`, `format_for`, `extract_capabilities`, `extract_citations` in Chat Completions, and `extract_tool_calls` in the Anthropic, Cohere, and Converse streams.

## Deploy Without Mixing Versions

Workers on 2.1 do not claim chats, so they can still overlap with workers on 2.2 while a deploy rolls out. Run the schema upgrade first, then let the new version replace every worker before you rely on claims. Chats that run once all workers are on 2.2 are covered.

Run your tests and deploy.

## Older Upgrade Guides

Use the [2.1 upgrade guide](https://github.com/crmne/ruby_llm/blob/v2.1.1/docs/_reference/upgrading.md), the [2.0 upgrade guide](https://github.com/crmne/ruby_llm/blob/v2.0.0/docs/_reference/upgrading.md), or the [1.16 upgrade guide](https://rubyllm.com/v1/upgrading/) for older releases. See [GitHub releases](https://github.com/crmne/ruby_llm/releases) for the full changelog.

---
name: rubyllm
description: Build and maintain Ruby or Rails applications with the RubyLLM AI framework. Use for chats, agents, tools, MCP servers, structured output, judgments, evaluations, media generation, transcription, OCR, moderation, embeddings, reranking, tracing, Rails integration, and RubyLLM upgrades; not for contributing to the framework itself.
license: MIT
metadata:
  api_version: "2.1"
---

# Build with RubyLLM

Use the application's installed RubyLLM version and existing conventions. This skill describes the 2.x API; features marked 2.1 need RubyLLM 2.1 or later. Read `Gemfile.lock`, or inspect the installed gem before choosing an API:

```bash
bundle exec ruby -rruby_llm -e 'puts RubyLLM::VERSION'
bundle show ruby_llm
```

For a 1.x application, use its version's documentation and keep the requested change on 1.x unless the user asks for an upgrade. Adding an AI feature does not require upgrading the application's framework.

## Choose the API for the task

RubyLLM has two public API families: conversations use chats, messages, tools, agents, structured output, streaming, and loop control; individual operations use `paint`, `animate`, `speak`, `transcribe`, `ocr`, `moderate`, `embed`, `rerank`, `judge`, `tokenize`, and `research`. Individual operations return typed results without requiring a chat. Some stream or have an asynchronous lifecycle.

Providers supply service endpoints, authentication, catalogs, and protocol selection. Protocols translate requests and responses. Both API families use this integration layer and shared services for model selection, configuration, accounting, and instrumentation. Build against the public API and let RubyLLM handle the service formats.

Rails integration adds persistence, attachments, streaming UI support, jobs, and generators around the same Ruby API.

## Find the relevant API

The installed gem's public method signatures and RDoc describe the code the application actually runs. Use them when online documentation differs. Find the matching version through [RubyLLM's documentation](https://rubyllm.com/). The root site documents the latest stable release. Unreleased changes on `main` are under [rubyllm.com/next/](https://rubyllm.com/next/), and 1.x under [rubyllm.com/v1/](https://rubyllm.com/v1/).

Read the relevant page instead of loading the entire documentation site:

| Task | Guide path under the matching documentation version |
| --- | --- |
| Understand the framework's structure | `overview/` |
| Configure a provider or select a model | `configuration/`, `configuration-providers/`, `models/` |
| Chat, stream, or attach files | `chat/`, `streaming/`, `attachments/` |
| Declare tools or require approval | `tools/`, `tool-parameters/`, `tool-execution/` |
| Use tools from MCP servers (2.1) | `mcp/` |
| Use provider-hosted tools such as web search | `provider-tools/`, `citations/` |
| Parse structured output | `structured-output/` |
| Build reusable agents | `agents/`, `prompt-rendering/` |
| Enable thinking or prompt caching | `thinking/`, `prompt-caching/` |
| Generate images or video | `image-generation/`, `video-generation/` |
| Generate speech or transcribe audio | `text-to-speech/`, `audio-transcription/` |
| Extract document text or moderate content | `ocr/`, `moderation/` |
| Embed text or rank search results | `embeddings/`, `rerank/`, `rag/` |
| Classify, score, or decide with typed answers (2.1) | `judgments/` |
| Measure answer quality against a dataset (2.1) | `evaluations/`, `evaluation-datasets/`, `evaluation-evaluators/`, `evaluation-running/`, `evaluation-examples/` |
| Count tokens, upload provider files, or run hosted research | `tokenization/`, `files/`, `hosted-research/` |
| Persist chats, attach files, or stream with Hotwire | `rails/`, `rails-persistence/`, `rails-streaming/`, `rails-generators/`, `rails-advanced-config/` |
| Resume agents in background jobs | `durable-agents/` |
| Track spend or handle failures | `cost-and-usage-tracking/`, `error-handling/` |
| Observe calls, group workflows, or trace with OpenTelemetry | `instrumentation/`, `opentelemetry/` (2.1) |
| Submit batches or drive the conversation loop | `batches/`, `agentic-workflows/` |
| Upgrade an existing application | `upgrading/` |

Markdown guides use the same name with `.md`, such as `chat.md`. The API reference starts at `api/RubyLLM.md`; class references include `api/RubyLLM/Chat.md` and `api/RubyLLM/Agent.md`. If fetching documentation is unavailable, inspect the installed source and identify any remaining uncertainty.

## Use the 2.x API consistently

- Configure credentials through `RubyLLM.configure`, following the application's secret storage. Select an existing configured provider. Verify explicit model IDs with `RubyLLM.models.find(id, provider: ...)`; do not invent IDs or use `assume_model_exists` to hide a typo.
- Start with `RubyLLM.chat` for a conversation. Set options with chainable `with_*` methods. Use `RubyLLM::Agent` when instructions, tools, or options should be reused. Ordinary Ruby methods and jobs compose workflows.
- Use individual operations directly for media, document processing, moderation, embeddings, and reranking. Read their typed results and use `save` on generated images, video, and speech. Check each operation's provider, model, and credentials; a configured chat provider may not offer every operation. `animate` waits for completion; use `animate_later` when the application needs to manage the job.
- `ask` runs the conversation and returns a message. `ask_later` stages input and returns the chat. For explicit loop control, use `generate`, `run_tools`, `step`, and `complete?`. Approval can park the loop before completion; inspect `awaiting_approval?` and resume after `approve` or `deny`.
- Read text through `message.content` and structured output through `message.parsed`. Declare schemas with `Schematist::Schema` or the schema DSL. Do not assume `content` is a parsed Hash.
- Subclass `RubyLLM::Tool`. Use `description`, `parameter`, or a `parameters` block, and keyword arguments on `execute`. Register tools with `with_tools`; configure choice and concurrency with `with_tool_options`. Keep application authorization in the tool or underlying service. Use `requires_approval` when the product needs a user's decision before execution. With large tool sets, pass `defer: true` to `with_tools` or `with_mcp` (or declare `defer` on the class) so the model searches for tools instead of receiving them all (2.1).
- Use `with_thinking`, `with_caching`, `with_compaction`, and `with_citations` without arguments to enable them and `false` to disable them. They reject `nil`. Read the relevant guide for supported options and model requirements.
- Connect MCP servers by subclassing `RubyLLM::MCP` (`url` or `command`, then `only` and `requires_approval` to shape tools) and attach them with `chat.with_mcp(...)` or the agent `mcp` macro (2.1). Do not add a separate MCP client gem.
- For a yes/no probability, a choice, or a score about application data, subclass `RubyLLM::Judge` and call `.judge(input)` instead of parsing free text from a chat (2.1). Backends are TypeSafe's Jev, OpenAI Decisions, and local decision models such as Clef with `provider: :ollama`.
- Use `with_fallbacks` for alternate models, `with_provider_tools` for provider-hosted tools, and `progress` inside a long-running tool with `after_tool_progress` on the chat (2.1) to report it.
- Use `RubyLLM.context` for per-tenant credentials or endpoints, and an agent `context` block when the configuration depends on the agent's inputs (2.1).
- Use shared RubyLLM options when available. Reserve `provider_options` for provider-specific request fields. Do not add a second provider SDK for functionality RubyLLM already supplies.
- Read tokens through `message.tokens.input`, `.output`, `.cache_read`, `.cache_write`, and `.thinking`; read cost through `message.cost.total`. Unknown cost is `nil`, not zero. The ledger includes individual attempts; a successful answer can include earlier failed attempts. Attribute usage with `owner:` on individual operations or `RubyLLM.with_usage_owner` (2.1). Persisted chat usage keeps both its chat and owner associations.
- Group related calls with `RubyLLM.workflow` and `workflow.step` for instrumentation. To send traces to an existing OpenTelemetry setup, call `RubyLLM::OpenTelemetry.enable` after configuring the SDK (2.1). RubyLLM never configures the SDK or exporters, and does not export prompts or responses.
- RubyLLM enums are Symbols: `finish_reason == :stop`, thinking effort `:high`. Provider slugs and model IDs remain Strings.

## Integrate with Rails

For a new integration, use `bin/rails generate ruby_llm:install`, review its migrations, and follow the application's migration workflow. Load packaged model data with `bin/rails ruby_llm:load_models`. `RubyLLM.models.refresh` performs a network refresh and persists the result.

Applications own their chat and message models, declared with `acts_as_chat` and `acts_as_message`. RubyLLM owns the supporting model, tool-call, usage, and batch tables, plus MCP credential and provider file tables from 2.1. Do not generate application `Model` or `ToolCall` classes from 1.x examples. Pass custom chat and message mappings to the generators when the application uses different names.

Use the same chat API on persisted records. Persisted `ask` returns the application's message record. Use the existing job backend for background work; retrieve and configure agents through their documented persistence API when a job resumes in another process. Prompt templates live under `app/prompts` by convention.

Pass Active Storage attachments through `with:` and retain the message attachment association set up by the install generator. For a Hotwire UI, use the Rails streaming guide or `ruby_llm:chat_ui` generator: persisted messages provide the targets for Turbo Streams. Individual operations work directly in Rails services and jobs with the same methods as plain Ruby.

For an upgrade, read the complete matching upgrade guide before editing migrations. Each release's upgrade covers only the changes since the previous release, so upgrade one release at a time; a 1.x application completes the 2.0 upgrade first. The 2.0 cutover requires preparation, backfill, finish, and application-specific reconciliation before affected activity resumes. Legacy-column cleanup is a later phase. Checkpoints make a stopped backfill resumable; retained columns do not make a 1.x code rollback safe. Rehearse against an isolated snapshot and respect the application's deployment and recovery process.

## Evaluate AI behavior

Specs check code; evaluations check how often the model gets the answer right (2.1). Put a `RubyLLM::Evaluation` subclass and its dataset in `app/evals`, named after the class (`support_evaluation.rb` and `support_evaluation.yml`). `perform(input)` runs the application and returns a string, Message, Chat, or Agent. Each case has `name`, `inputs`, and usually `expected_output`.

- Without declared criteria, a model checks each answer against `expected_output`, which every case must then supply. `evaluation :name, "statement"` declares criteria and replaces that default; `evaluation :correctness` without a description keeps it.
- `assertions` uses Minitest assertions with `output`, `tool_calls`, `messages`, `input`, `expected_output`, and `metadata`. Assertions do not turn off grading; `evaluator false` does. Outside Rails, assertions need `gem "minitest"`.
- Choose the grader with `evaluator model: ...`, an Agent class, or a Judge class with `evaluation :name, minimum: 0.8`.
- Run with `bin/rails "ruby_llm:eval[SupportEvaluation]"`, `SupportEvaluation.run`, or `evaluates SupportEvaluation` in RSpec or Minitest after extending `RubyLLM::Evaluation::RSpec` or `RubyLLM::Evaluation::Minitest`. Model grading costs money on every run, so keep graded evaluations out of the default test run unless the application records requests.

## Verify the application change

Run the application's relevant tests. Test tool business behavior, structured parsing, persisted conversation reconstruction, and job resumption where the change depends on them. Verify model calls with the application's existing recording or integration-test setup when needed; report which provider behavior was actually exercised. Keep the implementation within the requested feature and existing application architecture.

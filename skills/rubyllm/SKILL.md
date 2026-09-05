---
name: rubyllm
description: Build and maintain Ruby or Rails applications that use RubyLLM for AI features. Use for application integration, agents, tools, structured output, streaming, and RubyLLM upgrades; not for contributing to the framework itself.
license: MIT
metadata:
  api_version: "2.0"
---

# Build with RubyLLM

Use the application's installed RubyLLM version and existing conventions. This skill describes the 2.0 API. Read `Gemfile.lock`, or inspect the installed gem before choosing an API:

```bash
bundle exec ruby -rruby_llm -e 'puts RubyLLM::VERSION'
bundle show ruby_llm
```

For a 1.x application, use its version's documentation and keep the requested change on 1.x unless the user asks for an upgrade. Adding an AI feature does not require upgrading the application's framework.

## Find the relevant API

The installed gem's public method signatures and RDoc describe the code the application actually runs. Use them when online documentation differs. Find the matching version through [RubyLLM's documentation](https://rubyllm.com/). During the 2.0 release-candidate period, the 2.0 guides and Markdown API reference are under [rubyllm.com/next/](https://rubyllm.com/next/).

Read the relevant page instead of loading the entire documentation site:

| Task | Guide path under the matching documentation version |
| --- | --- |
| Configure a provider or select a model | `configuration/`, `configuration-providers/`, `models/` |
| Chat, stream, or attach files | `chat/`, `streaming/`, `attachments/` |
| Declare tools or require approval | `tools/`, `tool-parameters/`, `tool-execution/` |
| Parse structured output | `structured-output/` |
| Build reusable agents | `agents/`, `prompt-rendering/` |
| Persist chats or run background jobs | `rails/`, `rails-persistence/`, `rails-streaming/` |
| Track spend or handle failures | `cost-and-usage-tracking/`, `error-handling/` |
| Submit batches or drive the conversation loop | `batches/`, `agentic-workflows/` |
| Upgrade an existing application | `upgrading/` |

Markdown guides use the same name with `.md`, such as `chat.md`. The API reference starts at `api/RubyLLM.md`; class references include `api/RubyLLM/Chat.md` and `api/RubyLLM/Agent.md`. If fetching documentation is unavailable, inspect the installed source and identify any remaining uncertainty.

## Use the 2.0 API consistently

- Configure credentials through `RubyLLM.configure`, following the application's secret storage. Select an existing configured provider. Verify explicit model IDs with `RubyLLM.models.find(id, provider: ...)`; do not invent IDs or use `assume_model_exists` to hide a typo.
- Start with `RubyLLM.chat` for a conversation. Set options with chainable `with_*` methods. Use `RubyLLM::Agent` when instructions, tools, or options should be reused. Ordinary Ruby methods and jobs compose workflows.
- `ask` runs the conversation and returns a message. `ask_later` stages input and returns the chat. For explicit loop control, use `generate`, `run_tools`, `step`, and `complete?`. Approval can park the loop before completion; inspect `awaiting_approval?` and resume after `approve` or `deny`.
- Read text through `message.content` and structured output through `message.parsed`. Declare schemas with `Schematist::Schema` or the schema DSL. Do not assume `content` is a parsed Hash.
- Subclass `RubyLLM::Tool`. Use `description`, `parameter`, or a `parameters` block, and keyword arguments on `execute`. Register tools with `with_tools`; configure choice and concurrency with `with_tool_options`. Keep application authorization in the tool or underlying service. Use `requires_approval` when the product needs a user's decision before execution.
- Use `with_thinking`, `with_caching`, `with_compaction`, and `with_citations` without arguments to enable them and `false` to disable them. They reject `nil`. Read the relevant guide for supported options and model requirements.
- Use shared RubyLLM options when available. Reserve `provider_options` for provider-specific request fields. Do not add a second provider SDK for functionality RubyLLM already supplies.
- Read tokens through `message.tokens.input`, `.output`, `.cache_read`, `.cache_write`, and `.thinking`; read cost through `message.cost.total`. Unknown cost is `nil`, not zero. The ledger includes individual attempts; a successful answer can include earlier failed attempts.
- RubyLLM enums are Symbols: `finish_reason == :stop`, thinking effort `:high`. Provider slugs and model IDs remain Strings.

## Integrate with Rails

For a new integration, use `bin/rails generate ruby_llm:install`, review its migrations, and follow the application's migration workflow. Load packaged model data with `bin/rails ruby_llm:load_models`. `RubyLLM.models.refresh` performs a network refresh and persists the result.

Applications own their chat and message models, declared with `acts_as_chat` and `acts_as_message`. RubyLLM owns the supporting model, tool-call, usage, and batch tables. Do not generate application `Model` or `ToolCall` classes from 1.x examples. Pass custom chat and message mappings to the generators when the application uses different names.

Use the same chat API on persisted records. Persisted `ask` returns the application's message record. Use the existing job backend for background work; retrieve and configure agents through their documented persistence API when a job resumes in another process. Prompt templates live under `app/prompts` by convention.

For an upgrade, read the complete matching upgrade guide before editing migrations. The 2.0 cutover requires preparation, backfill, finish, and application-specific reconciliation before affected activity resumes. Legacy-column cleanup is a later phase. Checkpoints make a stopped backfill resumable; retained columns do not make a 1.x code rollback safe. Rehearse against an isolated snapshot and respect the application's deployment and recovery process.

## Verify the application change

Run the application's relevant tests. Test tool business behavior, structured parsing, persisted conversation reconstruction, and job resumption where the change depends on them. Verify model calls with the application's existing recording or integration-test setup when needed; report which provider behavior was actually exercised. Keep the implementation within the requested feature and existing application architecture.

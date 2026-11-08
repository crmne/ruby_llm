---
layout: default
title: What's New in 2.2
parent: "Release History"
nav_order: 0
description: Let models run Ruby, Python, JavaScript, and shell code in sandboxes on your own servers, let them ask for a wider sandbox one call at a time, teach them your workflows with skills, and run each persisted chat in one process at a time, in RubyLLM 2.2.
---

# {{ page.title }}

{{ page.description }}
{: .fs-6 .fw-300 }

After reading this guide, you will know:

* How to let a model run code in a sandbox on your own servers.
* What that code can see, and how the files it makes come back.
* How to give it gems, Python packages, and programs such as LibreOffice.
* How to measure each run.
* How sandboxes decide what code can do, and how the model asks for more.
* How skills teach the model your workflows, and run their scripts in the sandbox.
* How persisted chats now run in one process at a time, and resume after a crash or a deploy.
* How to queue messages while a chat runs, and attribute them as they join.
* How a tool asks the person who runs the chat, and how approvals became questions.
* How to keep a tool that shares state from running alongside others.
* How to run each tool inside a block, such as a tenant.
* How to keep tool results within the model's context window.
* How a tool ends the turn without another model call.
* How to retry without a parameter the model doesn't take.
* What a cancelled reply keeps.
* How to chat with Kimi models on Moonshot AI.
* How to chat with MiniMax's M3 models.
* How to chat with GLM models on Z.ai.
* How to chat with Meta's Muse models.
* How to speak with Google's Chirp 3: HD voices on Vertex AI.
* How to separate reasoning that a server leaves inside the answer.
* How to upgrade.

RubyLLM 2.2 lets a model run the code it writes, safely, on your own servers, lets it ask for more access one call at a time, teaches it your workflows with skills, and makes persisted chats safe to complete from several processes at once. For everything that arrived in 2.1, see [What's New in 2.1]({% link _reference/whats-new-in-2-1.md %}).

## Code Execution

A model that can run code calculates exactly, reshapes data, and makes files: charts, spreadsheets, PDFs, and presentations. Turn it on for a chat:

```ruby
# app/sandboxes/application_sandbox.rb
class ApplicationSandbox < MXC::Sandbox
  timeout 120
end

# config/initializers/ruby_llm.rb
RubyLLM.configure do |config|
  config.sandbox = "ApplicationSandbox"
end

chat = RubyLLM.chat.with_code_execution(python: %w[pandas matplotlib])
chat.ask "Plot monthly revenue from this export", with: "revenue.csv"

result = chat.messages.find(&:tool_result?)
result.attachments.first.filename # => "revenue.png"
```

Code execution needs [mxc](https://crmne.github.io/mxc/) 0.4.1 or later, so run `bundle update mxc` if you already use it.

The model gets one tool, `run_code`, that runs Ruby, Python, JavaScript, or a shell script. The code was written by a model, so it never runs in your application's process. It runs in a sandbox, a class built on the [mxc gem](https://crmne.github.io/mxc/), which uses the operating system's own isolation: Bubblewrap on Linux and Seatbelt on macOS. The sandbox holds the whole policy: what the code reads, writes, and reaches, and how long it runs. Without a configured sandbox, `with_code_execution` raises instead of running anything.

`with_code_execution` takes the same shape as `with_thinking` and `with_caching`, and agents declare it with a macro:

```ruby
class Analyst < RubyLLM::Agent
  code_execution languages: [:ruby, :python]
end
```

### What the Code Can See

Each call starts in a new, empty run directory. Files from the conversation are copied into it read-only, and every file the code writes comes back as an attachment on the tool result. In Rails, those attachments are stored with Active Storage like any other message file, so your interface can offer them for download.

The code sees the system's programs and libraries read-only, and nothing else: not your project, not your home directory, not your application's gems, and no network unless its sandbox allows it. In Rails, the application checks the sandbox when it boots, so a server that cannot run code fails at deploy time instead of in the middle of a conversation.

### Gems, Packages, and Programs

Declare the gems, Python packages, and npm packages the code may use. RubyLLM installs them once, inside a sandbox with network access limited to RubyGems, PyPI, or npm, and every run reads them from a cache:

```ruby
chat.with_code_execution(gems: %w[prawn caxlsx], python: %w[python-pptx openpyxl], npm: %w[pptxgenjs docx])
```

JavaScript runs on the Node.js your application's `PATH` finds, including one from mise or nvm.

To install nothing at runtime, bake the environments into your image and point at them:

```ruby
chat.with_code_execution(virtualenv: "/opt/sandbox/venv", gem_home: "/opt/sandbox/gems",
                         node_modules: "/opt/sandbox/node/node_modules")
```

Programs under `/usr`, such as LibreOffice and Poppler's `pdftoppm`, work without setup. Grant read access to programs or fonts installed elsewhere in the sandbox class, and give the code your own folders, such as templates, with `mounts:`.

### Measuring Runs

Each run emits a `code_execution.ruby_llm` event with its language, duration, exit code, and whether it timed out, and adds a `code_execution` entry with its CPU seconds to the usage ledger, so you can meter and bill runs. The upgrade migration widens the check constraint on the ledger's `operation` column for these rows; a constraint you added yourself [needs a migration of its own]({% link _reference/upgrading.md %}#code-runs-write-usage-rows). With OpenTelemetry, each run becomes a span.

### Your Own Sandbox

Besides an `MXC::Sandbox` class, a sandbox can be any class or object that answers `supported?` and `run`. Wrap a hosted sandbox service in that shape and set it as `config.sandbox`. To run code on the provider's servers instead, keep using `with_provider_tools(:code_execution)`.

See [Code Execution]({% link _advanced/code-execution.md %}) for every option.

## Asking for a Wider Sandbox

The default sandbox should be the smallest one that does the job. When the code needs more, such as changing files in a project or reaching the network, the model can ask for one call at a time:

```ruby
chat.with_code_execution(sandbox: ReadOnlySandbox, escalate_to: [WorkspaceSandbox, OnlineSandbox])
chat.ask "Add a changelog entry for the new export feature"

question = chat.pending_questions.first
question.tool_call.arguments # => {"code"=>"...", "sandbox"=>"workspace", "reason"=>"Edit CHANGELOG.md"}
question.approve
chat.complete
```

The model picks from the sandboxes you listed and says why. That one call waits for approval, like a `requires_approval` call, so the approval interface you already have keeps working. The next call runs in the default again. An escalated call is never remembered, there is no stored grant to widen, and RubyLLM checks the approval for that exact call right before it runs. A coding agent's ask, workspace, and skip-permissions modes become three choices of default and escalations.

`approve(tool_call, remember: true)` stops asking about an ordinary tool for the rest of the chat, in every process.

See [Sandboxes]({% link _advanced/sandboxes.md %}).

## Skills

Some tasks need a procedure, not a sentence: how your company formats an invoice, or the script that turns a spreadsheet into slides. Putting every procedure in every chat's instructions fills the model's context with work it rarely does. Skills keep them in folders, in the open [Agent Skills format](https://agentskills.io/specification), and the model loads one only when a task needs it:

```
app/skills/invoices/
├── SKILL.md
├── references/TAX_RULES.md
└── scripts/build_invoice.py
```

```ruby
chat = RubyLLM.chat.with_skills(:invoices).with_code_execution(python: %w[reportlab])
chat.ask "Bill order 1042 to ACME", with: "order-1042.json"
```

Every request lists each skill's name and description. The model loads a skill's instructions with its `load_skill` tool, and the files they mention with the same tool, one at a time. With code execution, each skill folder is mounted read-only in every run at `skills/<name>/`, so the skill's scripts run in the sandbox and the files they write come back as attachments.

`with_skills` with no arguments gives every skill in `app/skills`, engines add their own folders, and agents name theirs with `skills :invoices, :refunds`. A `SKILL.md` that breaks the specification raises when you configure the chat, not in the middle of a conversation. RubyLLM ships no skills and never downloads them.

See [Skills]({% link _tools/skills.md %}).

## File Stores

A 40-page PDF attached to the first question used to travel with every question after it, and a search that returned 30,000 characters stayed in every request. A chat with a file store keeps them out of the conversation:

```ruby
chat = RubyLLM.chat.with_file_store
chat.ask "Which clauses changed?", with: ["contract-v1.pdf", "contract-v2.pdf"]
chat.ask "Quote the new termination clause"
```

The model sees the PDFs on the question they came with, and one line naming each after that. It works with them through tools shaped like a coding agent's: `list_files` finds files by folder or glob, `search_files` greps them, `read_file` reads them with line numbers, and `write_file` and `edit_file` change them, refusing a file the model hasn't read or that changed since it read it. `edit_file` takes several changes across files in one call, all or none. `with_file_store(tools: :read)` gives a read-only agent, and `delete_file` is there when you ask for it. The tools read text files as they are, Word, Excel, and PowerPoint files with no setup, extracting their text as soon as they are attached, and PDFs, scans, and photos once you register the OCR converter, `RubyLLM::FileStore::Converters::OCR`. Other formats take a converter of your own, a few lines registered in `config.file_converters`. A tool result longer than its `inline_limit`, 10,000 characters by default, is saved as a file, and the model gets its start and the path. With code execution, code runs in the store's folder when it has one, like a coding agent's workspace, and otherwise copies in the files the model names and saves what it writes back.

Files live in memory, in a folder with `chat.with_file_store("tmp/work")`, or for a persisted chat in Active Storage, in the new `ruby_llm_chat_files` table. `chat.file_store` is the store, agents attach one with `file_store`, and a store of your own subclasses `RubyLLM::FileStore`.

See [File Stores]({% link _core_features/file-stores.md %}).

## A Generator for Every Building Block

Every building block now has a generator that puts it in its `app/` folder, ready to use:

```sh
bin/rails generate ruby_llm:mcp Linear https://mcp.linear.app/mcp
bin/rails generate ruby_llm:skill invoices "Bills an order to a customer as a PDF."
bin/rails generate ruby_llm:sandbox Workspace
bin/rails generate ruby_llm:evaluation Support
bin/rails generate ruby_llm:judge Urgency
```

They join `ruby_llm:agent`, `ruby_llm:tool`, and `ruby_llm:schema`, and each creates its folder, such as `app/skills` or `app/mcp`, when it first writes there. See [Generators]({% link _advanced/rails-generators.md %}#generators).

`acts_as_message` can now stream a chat to its page by itself: with `config.broadcast_messages = true`, it broadcasts new messages, chunks, and the finished reply with Turbo, and a job only needs `chat.complete(&:broadcast)`. The chat UI generator turns it on. Each chunk carries its position as `chunk.index`, so the generated chat UI puts chunks back in order even when Action Cable delivers them out of order. That Stimulus controller ships with RubyLLM, so `bundle update` keeps it current: in an app with an import map, RubyLLM pins it with `marked` and `dompurify`, and the generated file is one line. See [Streaming with Hotwire/Turbo]({% link _advanced/rails-streaming.md %}).

Agents get a parent, the way models have `ApplicationRecord`. `ruby_llm:install` creates `ApplicationAgent` with your chat model, and `ruby_llm:agent` generates subclasses of it. The chat UI talks to its own `ChatAgent`, so tools you add there show up in the UI, with a card for each question they ask, approvals included, and attachments for the files they return. See [Questions and Attachments]({% link _advanced/rails-generators.md %}#questions-and-attachments).

## One Process at a Time

A persisted chat now runs in one process at a time. `complete`, `step`, `generate`, `run_tools`, and `compact` claim the chat before they call the model or run a tool, and each tool call is claimed before it runs. A double-submitted approval that enqueues two jobs no longer runs a tool twice or asks the model for two replies:

```ruby
chat.complete
chat.running? # => true while another process runs the chat
```

A run that goes `config.max_run_time` without progress, ten minutes by default, counts as crashed, and so does a tool call that runs longer. A tool whose work takes longer can [pause its call]({% link _tools/tool-execution.md %}#long-running-tools).

If a process dies, its claims expire within a minute, on any number of servers, and the next job picks the chat up. See [Agents in Background Jobs]({% link _advanced/durable-agents.md %}#one-process-at-a-time).

No job backend runs a reply that a crash or a deploy cut off again by itself, so `Chat.interrupted` returns the chats whose run died holding its claim, and the chat UI generator writes `ResumeInterruptedChatsJob`, which answers them every minute through Solid Queue and once when the server boots:

```ruby
Chat.interrupted.find_each { |chat| ChatResponseJob.perform_later(chat.id) }
```

See [Resuming a Crashed Run]({% link _advanced/durable-agents.md %}#resuming-a-crashed-run).

## Queued Messages

People keep typing while an agent works. `queue` holds a message until the loop can take it, from any thread or, for a persisted chat, any process:

```ruby
chat.queue "Use the EU numbers, not the US ones"
chat.queue "Then draft the board summary", steer: false
```

A message that steers joins the turn that is running, after the next round of tool results. One queued with `steer: false` waits for the next turn. On a persisted chat, `queue` takes a `sender:`, and the message record is saved with it when your message model has a `sender` association. `around_join` wraps the moment a message joins. On a persisted chat it runs inside the transaction that creates the message, so you can set your own columns on it:

```ruby
chat.around_join { |queued, join| join.call(steered: queued.steer?) }
```

A block that never calls `join` withdraws the message, and so does `queued.withdraw`, for a Cancel button. `join_queued_messages` joins everything waiting without asking the model. See [Queueing Messages]({% link _advanced/agentic-workflows.md %}#queueing-messages) and [Queued Messages in Rails]({% link _advanced/rails-persistence.md %}#queued-messages).

## Subagents

An agent class now goes wherever tools go. The model hands it a task, a fresh agent does the work in its own conversation, and only its answer comes back:

```ruby
class SupportAgent < ApplicationAgent
  tools LookupOrder, ResearchAgent
end
```

A subagent like this has to finish within its call, so one that stops to wait raises `RubyLLM::ConfigurationError`. A subagent that waits for a person keeps its work in a [chat of its own]({% link _getting_started/agents.md %}#subagents-that-wait-for-a-person), behind a tool that pauses on a task until the person decides. Agents also declare chat callbacks once, `after_message :log_reply`, with `if:` and `unless:` like Rails. See [Subagents]({% link _getting_started/agents.md %}#subagents) and [Callbacks]({% link _getting_started/agents.md %}#callbacks).

## Tools Ask a Person

A tool can now ask the person who runs the chat something and carry on with the answer. The call pauses, no process waits, and `execute` runs again from the top once they answer, so ask first, then act:

```ruby
class BookFlight < RubyLLM::Tool
  description "Books a flight"
  parameter :destination, description: "The city to fly to"

  def execute(destination:)
    seat = ask("Window or aisle?", choices: %w[window aisle]) or return "No seat chosen."
    Flights.book!(destination, seat:)
  end
end
```

`ask` takes free text, one of `choices:`, the fields a block declares, or a page to visit. An approval is a question too, answered yes or no, and MCP servers ask theirs the same way. `pending_questions` lists them all, and you answer each with `answer`, `approve`, or `decline`, which takes a note for the model, from any process in Rails:

```ruby
chat.pending_questions.first.answer "window"
chat.complete
```

See [Asking a Person]({% link _tools/tool-execution.md %}#asking-a-person).

## Exclusive Tools

Tools that share state, such as a browser page, can now run by themselves while the rest of a concurrent round runs in parallel:

```ruby
class BrowserClick < RubyLLM::Tool
  exclusive
end
```

See [Exclusive Tools]({% link _tools/tool-execution.md %}#exclusive-tools).

## Wrapping Tool Calls

`around_tool_call` runs each tool inside your block, in the thread or fiber that runs it, so tenants and `Current` attributes reach tools that run concurrently:

```ruby
chat.around_tool_call { |call, &run| ActsAsTenant.with_tenant(account, &run) }
```

Agents declare it once, `around_tool_call :in_tenant`, and Rails chat records take it too. See [Wrapping Tool Calls]({% link _core_features/chat-callbacks.md %}#wrapping-tool-calls).

## Context Budgets

A context budget keeps long tool results from filling the context window. It cuts a result longer than its share when it is added, and leaves the oldest results out of a request that would take more than its share, in steps that keep the prompt cache warm. Set it once for every chat and agent:

```ruby
RubyLLM.configure do |config|
  config.context_budget = { per_result: 0.25, per_request: 0.7 }
end
```

New Rails applications get this line from the install generator. A chat or agent can set its own with `with_context_budget` or the `context_budget` macro, or turn it off with `nil`:

```ruby
chat.with_context_budget(per_result: 0.1, per_request: 0.5)
```

For a model the registry has no window for, pass it: `chat.with_context_budget(window: 128_000, per_request: 0.7)`.

The budget is off until you set it, and it only cuts the text of tool results: attachments and long tool call arguments still count against the window.

`Message#with(content:)` returns a changed copy of a message, for shaping the transcript yourself. See [Keeping Tool Results in Budget]({% link _core_features/chat-request-control.md %}#keeping-tool-results-in-budget).

## Ending the Turn from a Tool

A tool that says the last word can end the turn without another model call:

```ruby
def execute(category:)
  ticket.update!(category:)
  halt "Filed as #{category}"
end
```

The round finishes, `ask` returns the halted result, and the chat is `complete?`. See [Ending the Turn]({% link _tools/tool-execution.md %}#ending-the-turn).

## Dropping Unsupported Parameters

When an OpenAI model doesn't take a parameter, such as a temperature, the rejection now raises `RubyLLM::UnsupportedParameterError`, with `parameter` naming it. Opt in, and the chat retries each model without it before moving on to the next. Other providers' rejections stay `BadRequestError`:

```ruby
chat.with_temperature(0.2).with_fallbacks(drop_unsupported: true)
```

See [Dropping Unsupported Parameters]({% link _advanced/error-handling.md %}#dropping-unsupported-parameters).

## Cancelled Replies Keep Their Text

A streamed reply you cancel now stays in the conversation as far as it got, marked `cancelled?`, so the model sees what the person read. See [Cancelling a Stream]({% link _core_features/streaming.md %}#cancelling-a-stream).

## Tests Without a Provider

`RubyLLM::TestHelper` scripts what the model replies, so your tests run your real chats, agents, and pages with no provider and no API key:

```ruby
require "ruby_llm/test_helper"

class SupportAgentTest < ActiveSupport::TestCase
  include RubyLLM::TestHelper

  test "calls the tool and answers" do
    stub_replies tool_call(:weather, city: "Berlin"), "It is sunny.", cost: 0.01

    assert_equal "It is sunny.", SupportAgent.new.ask("Weather?").content
  end
end
```

Replies stream, and `interval:` slows them down so a test can press Stop. See [Testing]({% link _advanced/testing.md %}).

## Smaller Additions

`response.web_sources` lists the pages a hosted web search returned, the same on OpenAI, Azure, Meta, xAI, Anthropic, Gemini, and Vertex AI. They come from the outside world, so don't treat them as an allowlist on their own. See [Web Sources]({% link _tools/provider-tools.md %}#web-sources).

`rescue_from` on a tool turns its exceptions into results the model reads, as on an agent. Declare it on a base tool class, on `RubyLLM::Tool` for every tool, on `RubyLLM::CodeExecution`, or on an MCP server's class for its tools. Handlers run for the calls a chat makes. Calling a tool yourself with `call` or `execute` works as it did in 2.1, without handlers, so its exceptions reach your code. See [Tool-Level Handlers]({% link _advanced/error-handling.md %}#tool-level-handlers).

Prompt caching and fallbacks work together across providers. A fallback leaves out the caching options its provider has no use for, such as an OpenAI cache key on Claude, and a persisted chat with caching on sends a stable cache key of its own, so `caching` alone is enough. See [Caching with Fallbacks]({% link _core_features/prompt-caching.md %}#caching-with-fallbacks).

A reply a fallback model wrote names it: `reply.model` and `reply.provider`, also on Rails records with those columns. See [Fallback Callbacks]({% link _advanced/error-handling.md %}#fallback-callbacks).

`config.code_execution_max_file_size` raises the 10 MB cap on a file [code execution]({% link _advanced/code-execution.md %}#limits) returns, for code that makes videos or large exports.

A chat with a [file store]({% link _core_features/file-stores.md %}#what-the-model-sees) says what it sent in part: a tool result kept in a file names it in `spilled_path`, and the start of a long attachment is `partial?`.

`RubyLLM::MCP::Client#meta` returns the `_meta` RubyLLM sends with every request to a server on the 2026-07-28 revision, for requests your app sends a server itself. See [Custom Transports]({% link _tools/mcp.md %}#custom-transports).

`RubyLLM.paint` takes `fallbacks:`, the models to try when the first is rate limited or overloaded, as `with_fallbacks` does for chats. See [Falling Back to Another Model]({% link _getting_started/image-generation.md %}#falling-back-to-another-model).

`RubyLLM::Attachment.new(io, filename: "export.csv", mime_type: "text/csv")` takes a file's type when you know it. See [Automatic File Type Detection]({% link _core_features/attachments.md %}#automatic-file-type-detection).

A chat bills its owner, set with `chat.with_owner(current_user)`, or in Rails named once with `acts_as_chat owner: :user`, which keeps the chat's files for that user too. See [One-Shot Operations]({% link _core_features/cost-and-usage-tracking.md %}#one-shot-operations).

Vertex AI takes the `eu` and `us` multi-region locations.

The generated chat UI switches a chat's model mid-conversation. The message form has the same model picker as the new-chat form, and a message sent with another model moves the chat to it with `with_model`, so that reply and every later one use it. See [Adding a Chat UI]({% link _advanced/rails-generators.md %}#adding-a-chat-ui).

`config.ssl` sets TLS options for every connection, globally or in a context, so a self-hosted server behind an internal certificate authority works without process-wide certificate variables: `config.ssl = { ca_file: "/certs/internal-ca.pem" }`. See [TLS Options]({% link _reference/configuration-connection.md %}#tls-options) ([#1525](https://github.com/crmne/ruby_llm/issues/1525)).

## Moonshot AI

Moonshot AI joins the built-in providers, bringing the total to twenty. Its Kimi models read text and images, think before they answer, and call tools:

```ruby
RubyLLM.chat(model: "kimi-k3").ask "Hello from Kimi"
```

Set `moonshot_api_key` to a key from the Kimi platform. See [Provider Setup]({% link _reference/configuration-providers.md %}#moonshot-ai).

## MiniMax

MiniMax joins the built-in providers, bringing the total to twenty-one. Its M3 models read text and images, think before they answer, and call tools:

```ruby
RubyLLM.chat(model: "MiniMax-M3.1-Flash").ask "Hello from MiniMax"
```

Set `minimax_api_key` to a key from the MiniMax platform. See [Provider Setup]({% link _reference/configuration-providers.md %}#minimax).

## Z.ai

Z.ai joins the built-in providers, bringing the total to twenty-two. It serves Zhipu's GLM models, which think before they answer, call tools, and, in GLM-5.3 Flash and FlashX and the vision models, read images:

```ruby
RubyLLM.chat(model: "glm-5.3").ask "Hello from Z.ai"
```

Set `zai_api_key` to a key from Z.ai, or point `zai_api_base` at BigModel for Zhipu's platform in China. See [Provider Setup]({% link _reference/configuration-providers.md %}#zai).

## Meta

Meta joins the built-in providers, bringing the total to twenty-three. Its Muse models read text, images, and PDFs, think before they answer, call tools, and search the web:

```ruby
RubyLLM.chat(model: "muse-spark-1.3").ask "Hello from Muse"
```

Set `meta_api_key` to a key from dev.meta.ai. See [Provider Setup]({% link _reference/configuration-providers.md %}#meta).

## Chirp 3: HD Voices on Vertex AI

Vertex AI now speaks with Google's Chirp 3: HD voices through Cloud Text-to-Speech, from the endpoint of your `vertexai_location`:

```ruby
RubyLLM.speak("Willkommen zurück.", model: "{{ site.models.speech_vertexai }}",
                                    voice: "de-DE-Chirp3-HD-Leda").save("welcome.mp3")
```

See [Text to Speech]({% link _getting_started/text-to-speech.md %}) and [Provider Setup]({% link _reference/configuration-providers.md %}#text-to-speech).

## Judgments on OpenRouter

OpenRouter's decision models now answer [judgments]({% link _advanced/judgments.md %}): Jev, Clef, and every other model it lists under decisions. Each judgment reports the exact cost OpenRouter charged:

```ruby
judgment = RubyLLM.judge("Please refund the duplicate charge today.",
                         model: "{{ site.models.openrouter_judgment }}", provider: :openrouter,
                         questions: { urgent: { type: :probability, instructions: "Does this need attention today?" } })
judgment.cost.total # => what OpenRouter charged, in US dollars
```

Clef Omni also judges audio and video passed with `with:`.

## Reasoning Inside the Answer

Some OpenAI-compatible servers, such as llama.cpp with `--reasoning-format none`, leave the model's reasoning in the answer, wrapped in `<think>` tags. Turn on `split_think_tags` and RubyLLM moves a leading `<think>` block into `thinking`, in complete and streamed responses alike:

```ruby
RubyLLM.configure do |config|
  config.openai_api_base = "http://localhost:8080/v1" # llama.cpp
  config.openai_protocol = :chat_completions
  config.split_think_tags = true
end

chat = RubyLLM.chat(model: "qwen3", provider: :openai, assume_model_exists: true)
response = chat.ask "What is 15 * 23?"
response.content        # => "345"
response.thinking.text  # => "15 * 20 is 300, and 15 * 3 is 45..."
```

It is off by default, and a context can turn it on for one server. See [Reasoning Inside the Answer]({% link _core_features/thinking.md %}#reasoning-inside-the-answer).

## Fixes

Saving a chat on an empty `ruby_llm_models` table still loads the whole model registry, but only once per database and process. Transactional tests roll that load back after every test, and each test that saved a chat used to load the registry again ([#1554](https://github.com/crmne/ruby_llm/issues/1554)).

An MCP server that answers HTTP 429 or a 5xx status while a chat lists its tools, or whose stdio process exits, now sits out the turn like one that can't be reached, instead of raising from `ask`. A 429 or 503 with `Retry-After` waits as long as the server asks. A tool call the server fails the same way, or answers with a JSON-RPC error, gives the model a tool error and the turn goes on, where it used to raise. Building or finding an agent whose tool choice names a server's tool no longer contacts its MCP servers, which now happens only when the chat first needs their tools. See [When a Server Is Down]({% link _tools/mcp.md %}#when-a-server-is-down).

## Upgrades

`bin/rails generate ruby_llm:upgrade` in 2.2 adds the columns chats and tool calls use for their claims, the tables for queued messages and chat files, and an `ApplicationAgent` for your agents to inherit from. Applications on 2.0 upgrade to 2.1 first. See [Upgrading]({% link _reference/upgrading.md %}).

2.2 deprecates iterating a chat directly and `chat.cache_until_here` in favor of `chat.messages` and marking the message itself, and renames `RubyLLM.with_usage_owner` to `RubyLLM.with_owner`. The old names still work and warn, and RubyLLM 3.0 removes them. See [Read a Conversation Through `messages`]({% link _reference/upgrading.md %}#read-a-conversation-through-messages).

`waiting?`, `pending_questions`, and `pending_tasks` now say what a chat waits on. `pending_questions` lists approvals and questions alike, and `pending_approvals`, `awaiting_approval?`, `pending_inputs`, `awaiting_input?`, and `awaiting_tasks?` are gone. Evaluation evidence for a chat lists `pending_questions` in place of `pending_approvals`, with every question's id. `deny` is gone too: `decline` says no to every question, with an optional note the model sees, or a Hash the model gets as a declined call's result. The upgrade guide gives each one's replacement. Answers to a server's questions are now checked against what they ask, so an extra field or a choice the question doesn't offer raises `ArgumentError`, and a server's request to visit anything but an `http` or `https` page is declined. See [Two Lists and `decline` Replace Seven Methods]({% link _reference/upgrading.md %}#two-lists-and-decline-replace-seven-methods) and [Approvals and Questions Are One List]({% link _reference/upgrading.md %}#approvals-and-questions-are-one-list).

Provider gems and custom providers that override protocol methods rename them: methods that build a request start with `render_`, methods that read a response start with `parse_`, and the capability predicates drop `supports_` ([#1136](https://github.com/crmne/ruby_llm/pull/1136)). See [Rename Protocol Method Overrides]({% link _reference/upgrading.md %}#rename-protocol-method-overrides).

## Try 2.2

RubyLLM 2.2 requires Ruby 3.2 or later. Install it:

```sh
bundle add ruby_llm --version "~> 2.2.0"
```

Start with [Getting Started]({% link _getting_started/getting-started.md %}), or follow [Upgrading]({% link _reference/upgrading.md %}) to update a 2.1 application.

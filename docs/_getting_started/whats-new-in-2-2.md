---
layout: default
title: What's New in 2.2
nav_order: 4
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
* How persisted chats now run in one process at a time.
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

Each run emits a `code_execution.ruby_llm` event with its language, duration, exit code, and whether it timed out, so you can meter and bill runs. With OpenTelemetry, each run becomes a span.

### Your Own Sandbox

Besides an `MXC::Sandbox` class, a sandbox can be any class or object that answers `supported?` and `run`. Wrap a hosted sandbox service in that shape and set it as `config.sandbox`. To run code on the provider's servers instead, keep using `with_provider_tools(:code_execution)`.

See [Code Execution]({% link _core_features/code-execution.md %}) for every option.

## Asking for a Wider Sandbox

The default sandbox should be the smallest one that does the job. When the code needs more, such as changing files in a project or reaching the network, the model can ask for one call at a time:

```ruby
chat.with_code_execution(sandbox: ReadOnlySandbox, escalate_to: [WorkspaceSandbox, OnlineSandbox])
chat.ask "Add a changelog entry for the new export feature"

chat.pending_approvals.first.arguments # => {"code"=>"...", "sandbox"=>"workspace", "reason"=>"Edit CHANGELOG.md"}
chat.approve(chat.pending_approvals.first)
chat.complete
```

The model picks from the sandboxes you listed and says why. That one call waits for approval, like a `requires_approval` call, so the approval interface you already have keeps working. The next call runs in the default again. An escalated call is never remembered, there is no stored grant to widen, and RubyLLM checks the approval for that exact call right before it runs. A coding agent's ask, workspace, and skip-permissions modes become three choices of default and escalations.

`approve(tool_call, remember: true)` stops asking about an ordinary tool for the rest of the chat, in every process.

See [Sandboxes]({% link _core_features/sandboxes.md %}).

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

`with_skills` with no arguments gives every skill in `app/skills`, engines add their own folders, and agents name theirs with `skills :invoices, :refunds`. A `SKILL.md` that breaks the specification raises when you configure the chat, not in the middle of a conversation. `RubyLLM::Skill::Marketplace.add("anthropics/skills")` copies the skills of a plugin marketplace into `vendor/skills` for you to review and commit, where `with_skills` finds them after `app/skills`. RubyLLM ships no skills, and never downloads them when a chat runs.

See [Skills]({% link _core_features/skills.md %}).

## A Generator for Every Building Block

Every building block now has a generator that puts it in its `app/` folder, ready to use:

```sh
bin/rails generate ruby_llm:mcp Linear https://mcp.linear.app/mcp
bin/rails generate ruby_llm:skill invoices "Bills an order to a customer as a PDF."
bin/rails generate ruby_llm:sandbox Workspace
bin/rails generate ruby_llm:evaluation Support
bin/rails generate ruby_llm:judge Urgency
```

They join `ruby_llm:agent`, `ruby_llm:tool`, and `ruby_llm:schema`. `ruby_llm:install` creates every folder, including the new `app/skills`, `app/sandboxes`, `app/mcp`, `app/evals`, and `app/judges`. See [Generators]({% link _advanced/rails-generators.md %}#generators).

`acts_as_message` can now stream a chat to its page by itself: with `config.broadcast_messages = true`, it broadcasts new messages, chunks, and the finished reply with Turbo, and a job only needs `chat.complete(&:broadcast)`. The chat UI generator turns it on. Each chunk carries its position as `chunk.index`, so the generated chat UI puts chunks back in order even when Action Cable delivers them out of order. See [Streaming with Hotwire/Turbo]({% link _advanced/rails-streaming.md %}).

Agents get a parent, the way models have `ApplicationRecord`. `ruby_llm:install` creates `ApplicationAgent` with your chat model, and `ruby_llm:agent` generates subclasses of it. The chat UI talks to its own `ChatAgent`, so tools you add there show up in the UI, with approval cards for the ones that require approval and attachments for the files they return. See [Approvals and Attachments]({% link _advanced/rails-generators.md %}#approvals-and-attachments).

## One Process at a Time

A persisted chat now runs in one process at a time. `complete`, `step`, `generate`, `run_tools`, and `compact` claim the chat before they call the model or run a tool, and each tool call is claimed before it runs. A double-submitted approval that enqueues two jobs no longer runs a tool twice or asks the model for two replies:

```ruby
chat.complete
chat.running? # => true while another process runs the chat
```

A claim lasts `config.max_run_time`, ten minutes by default. A tool that legitimately runs longer declares its own:

```ruby
class RenderVideo < RubyLLM::Tool
  max_run_time 2.hours
end
```

If a process dies, its claims expire and another process picks the chat up. See [Durable Agents]({% link _advanced/durable-agents.md %}#one-process-at-a-time).

## Upgrades

`bin/rails generate ruby_llm:upgrade` in 2.2 adds the columns chats and tool calls use for their claims, and any of the conventional `app/` folders your application lacks, such as `app/skills` and `app/sandboxes`. Applications on 2.0 upgrade to 2.1 first. See [Upgrading]({% link _reference/upgrading.md %}).

## Try 2.2

RubyLLM 2.2 requires Ruby 3.2 or later. Install it:

```sh
bundle add ruby_llm --version "~> 2.2.0"
```

Start with [Getting Started]({% link _getting_started/getting-started.md %}), or follow [Upgrading]({% link _reference/upgrading.md %}) to update a 2.1 application.

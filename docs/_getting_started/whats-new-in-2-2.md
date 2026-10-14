---
layout: default
title: What's New in 2.2
nav_order: 4
description: Let models run Ruby, Python, and shell code in a sandbox on your own servers, decide which tool calls run with permission modes, and run each persisted chat in one process at a time, in RubyLLM 2.2.
---

# {{ page.title }}

{{ page.description }}
{: .fs-6 .fw-300 }

After reading this guide, you will know:

* How to let a model run code in a sandbox on your own servers.
* What that code can see, and how the files it makes come back.
* How to give it gems, Python packages, and programs such as LibreOffice.
* How to measure each run.
* How permission modes decide which tool calls run, wait, or are denied.
* How persisted chats now run in one process at a time.
* How to upgrade.

RubyLLM 2.2 lets a model run the code it writes, safely, on your own servers, lets you decide how much it may do without asking, and makes persisted chats safe to complete from several processes at once. For everything that arrived in 2.1, see [What's New in 2.1]({% link _reference/whats-new-in-2-1.md %}).

## Code Execution

A model that can run code calculates exactly, reshapes data, and makes files: charts, spreadsheets, PDFs, and presentations. Turn it on for a chat:

```ruby
RubyLLM.configure do |config|
  config.sandbox = :mxc
end

chat = RubyLLM.chat.with_code_execution(python: %w[pandas matplotlib])
chat.ask "Plot monthly revenue from this export", with: "revenue.csv"

result = chat.messages.find(&:tool_result?)
result.attachments.first.filename # => "revenue.png"
```

The model gets one tool, `run_code`, that runs Ruby, Python, or a shell script. The code was written by a model, so it never runs in your application's process. It runs in a sandbox built on the [mxc gem](https://crmne.github.io/mxc/), which uses the operating system's own isolation: Bubblewrap on Linux and Seatbelt on macOS. Without a configured sandbox, `with_code_execution` raises instead of running anything.

`with_code_execution` takes the same shape as `with_thinking` and `with_caching`, and agents declare it with a macro:

```ruby
class Analyst < RubyLLM::Agent
  code_execution languages: [:ruby, :python], timeout: 120
end
```

### What the Code Can See

Each call starts in a new, empty working directory. Files from the conversation are copied into it read-only, and every file the code writes comes back as an attachment on the tool result. In Rails, those attachments are stored with Active Storage like any other message file, so your interface can offer them for download.

The code sees the system's programs and libraries read-only, and nothing else: not your project, not your home directory, not your application's gems, and no network unless you grant it. In Rails, the application checks the sandbox when it boots, so a server that cannot run code fails at deploy time instead of in the middle of a conversation.

### Gems, Packages, and Programs

Declare the gems and Python packages the code may use. RubyLLM installs them once, inside the sandbox with network access limited to RubyGems or PyPI, and every run reads them from a cache:

```ruby
chat.with_code_execution(gems: %w[prawn caxlsx], python: %w[python-pptx openpyxl])
```

To install nothing at runtime, bake the environments into your image and point at them:

```ruby
chat.with_code_execution(virtualenv: "/opt/sandbox/venv", gem_home: "/opt/sandbox/gems")
```

Programs under `/usr`, such as LibreOffice and Poppler's `pdftoppm`, work without setup. Grant read access to programs or fonts installed elsewhere with `readable:`.

### Measuring Runs

Each run emits a `code_execution.ruby_llm` event with its language, duration, exit code, and whether it timed out, so you can meter and bill runs. With OpenTelemetry, each run becomes a span.

### Your Own Sandbox

A sandbox is any object that answers `supported?` and `run`. Wrap a hosted sandbox service in that shape and set it as `config.sandbox`. To run code on the provider's servers instead, keep using `with_provider_tools(:code_execution)`.

See [Code Execution]({% link _core_features/code-execution.md %}) for every option.

## Permissions

Approvals used to be a property of each tool. Permission modes set them for the whole chat, so one line decides how much the model may do on its own:

```ruby
chat.with_permissions(:read_only)  # read-only tools run, everything else is denied
chat.with_permissions(:ask)        # read-only tools run, everything else waits for approval
chat.with_permissions(:auto, allow: [SearchDocs, { network: ["pypi.org", "files.pythonhosted.org"] }])
chat.with_permissions(:dangerous)  # everything runs, still in the sandbox
```

Mark the tools that change nothing with `read_only`, and MCP tools follow their server's `readOnlyHint`. Calls that wait look exactly like `requires_approval` calls, so the approval interface you already have keeps working. `approve(tool_call, remember: true)` stops asking about that tool for the rest of the chat.

With code execution, the model can ask for more with a `request_permission` tool: a network host such as `pypi.org`, or a path on your server, with its reason. Once you grant a package registry, it can `gem install` and `pip install` into an environment kept for the chat. Persisted chats store their mode and grants, so an approval in one process takes effect in the job that resumes the chat. Agents declare a starting mode with `permissions :ask`.

See [Permissions]({% link _core_features/permissions.md %}).

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

`bin/rails generate ruby_llm:upgrade` in 2.2 adds the columns chats and tool calls use for their claims, and the `permissions` and `permission_grants` columns chats use to keep their permission mode. Applications on 2.0 upgrade to 2.1 first. See [Upgrading]({% link _reference/upgrading.md %}).

## Try 2.2

RubyLLM 2.2 requires Ruby 3.2 or later. Install it:

```sh
bundle add ruby_llm --version "~> 2.2.0"
```

Start with [Getting Started]({% link _getting_started/getting-started.md %}), or follow [Upgrading]({% link _reference/upgrading.md %}) to update a 2.1 application.

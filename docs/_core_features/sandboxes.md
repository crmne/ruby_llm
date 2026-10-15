---
layout: default
title: Sandboxes
parent: "Tools"
nav_order: 7
description: Decide what code from a model can read, write, and reach, and let the model ask for more one call at a time.
---

# {{ page.title }}

{{ page.description }}
{: .fs-6 .fw-300 }

After reading this guide, you will know:

* What a sandbox is and how to define one.
* Where sandbox classes live in a Rails application.
* How a chat picks its default sandbox.
* How the model asks to run one call in a wider sandbox, and how you approve it.
* Why escalation is safe by construction.
* How to build a coding agent with ask, workspace, and unrestricted modes.
* How to set up a server application that never escalates.
* How to plug in a sandbox of your own.

## What a Sandbox Is

[Code execution]({% link _core_features/code-execution.md %}) runs code a model wrote. That code never runs in your application's process. It runs in a sandbox, and the sandbox decides everything the code may do: which paths it reads, which it changes, which hosts it reaches, where it starts, and how long it runs.

A sandbox is a class. RubyLLM's sandboxes come from the [mxc gem](https://crmne.github.io/mxc/), which uses Bubblewrap on Linux, Seatbelt on macOS, and process containers on Windows:

```ruby
# Gemfile
gem "mxc"
```

Subclass `MXC::Sandbox` and declare its policy with class macros. In Rails, each sandbox is a class in `app/sandboxes`:

```ruby
# app/sandboxes/read_only_sandbox.rb
class ReadOnlySandbox < MXC::Sandbox
  timeout 120
end

class WorkspaceSandbox < MXC::Sandbox
  directory Rails.root.join("storage/workspace")
  writable Rails.root.join("storage/workspace")
  timeout 300
end

class OnlineSandbox < MXC::Sandbox
  network allow: ["pypi.org", "files.pythonhosted.org", "api.github.com"]
  timeout 300
end
```

`bin/rails generate ruby_llm:sandbox Workspace` creates `app/sandboxes/workspace_sandbox.rb` with a two-minute timeout.

`MXC::Sandbox` on its own reads the system's programs and libraries, writes nothing, and has no network. Each macro widens it: `readable` and `writable` add paths, `network` opens the network or lists hosts, `directory` sets where the code starts, and `timeout` sets how long it may run. `limits` and `priority` bound what it may use. A sandbox without a timeout stops runs after 120 seconds. See [mxc's policies](https://crmne.github.io/mxc/policies/) for every setting.

The class holds the whole policy. RubyLLM adds only what a run needs to work: a fresh run directory with the conversation's files and your [mounted folders]({% link _core_features/code-execution.md %}#your-own-folders), the Ruby and Node.js installations, and the [packages]({% link _core_features/code-execution.md %}#packages) you declared. It never widens the sandbox in any other way.

## The Default Sandbox

Name the sandbox every chat uses in your configuration:

```ruby
RubyLLM.configure do |config|
  config.sandbox = "ReadOnlySandbox"
end
```

The name is a String because the initializer runs while Rails boots, before it can load your application's classes. RubyLLM looks the class up whenever a chat needs it, so the sandboxes in `app/sandboxes` autoload and reload like the rest of your code. Outside Rails, pass the class itself. Everywhere else, such as in agents and chats, use the class: `escalate_to: [WorkspaceSandbox]`.

`bin/rails generate ruby_llm:install` creates `app/sandboxes`, and the 2.2 upgrade generator adds it to existing applications. RubyLLM does not depend on mxc: add it to your Gemfile when you run code, and Bundler loads it like any other gem.

Without `config.sandbox`, nothing runs locally, and turning on code execution raises `RubyLLM::ConfigurationError`. Check that the sandbox works on this machine:

```ruby
RubyLLM.sandbox.supported? # => true
```

In Rails, RubyLLM checks this when the application boots and raises `RubyLLM::ConfigurationError` with the reason and how to fix it, so a server that cannot run code fails at deploy time instead of in the middle of a conversation. Build-time boots that set `SECRET_KEY_BASE_DUMMY`, such as `assets:precompile` in a Docker build, skip the check. See [Checking the Host](https://crmne.github.io/mxc/checking-the-host/) for what each platform needs.

A chat can use another default with `sandbox:`:

```ruby
chat.with_code_execution(sandbox: WorkspaceSandbox)
```

Make the default the smallest sandbox that does the job. Everything wider is reached by asking.

## Asking for a Wider Sandbox

List the sandboxes the model may ask for with `escalate_to:`:

```ruby
chat = RubyLLM.chat.with_code_execution(
  sandbox: ReadOnlySandbox,
  escalate_to: [WorkspaceSandbox, OnlineSandbox]
)
```

Each sandbox gets a name from its class: `WorkspaceSandbox` is `workspace` and `OnlineSandbox` is `online`. To choose the names yourself, pass a Hash such as `escalate_to: { files: WorkspaceSandbox }`.

The `run_code` tool now takes two more arguments: `sandbox`, one of those names, and `reason`, why the code needs it. Its description tells the model what each sandbox allows. A call without `sandbox` runs in the default, without asking. A call that names one waits for a decision:

```ruby
chat.ask "Add a changelog entry for the new export feature"

call = chat.pending_approvals.first
call.arguments
# => {"language"=>"shell", "code"=>"...", "sandbox"=>"workspace", "reason"=>"Edit CHANGELOG.md in the project"}
chat.tools[:run_code].summary(call.arguments["sandbox"])
# => "Starts in /srv/app/storage/workspace. Can change /srv/app/storage/workspace. No network access. Stops after 300 seconds."

chat.approve(call)
chat.complete
```

Show the person the code, the reason, and the summary before they decide. `approve` runs that one call in the named sandbox, and `deny` refuses it: the model learns the user said no, and continues. These calls are ordinary [tool approvals]({% link _core_features/tool-execution.md %}#requiring-approval), so the approval interface you already have works for them.

Escalation is per call. The next call runs in the default sandbox again unless it asks again, and every call that asks waits for its own decision. An escalated call is never remembered: `approve(call, remember: true)` raises `ArgumentError` for it, so no approval can turn into standing access.

The model never sees a sandbox argument when `escalate_to:` is empty. Sandboxes that cannot run on this machine, such as one with a host list on Windows, are left out of the list.

## Why Escalation Is Safe

Escalation is built so that a mistake or a hostile model cannot widen what code can do:

* **No stored state.** There is no current sandbox and no grant list. Each run's sandbox comes only from its own arguments and the decision recorded for that call.
* **A fixed list of names.** The model picks from the names you listed. An unknown name is an error the model sees, never the default or something wider, and nothing runs.
* **Approval belongs to one call.** It is recorded on that call's id, and it covers exactly the code and sandbox that call carries.
* **Checked right before running.** Just before an escalated run starts, RubyLLM checks again that the call names that sandbox, carries that code, and has its approval on record. A call that reaches the tool any other way, such as a direct `call`, is refused.
* **Used once.** An approval runs its call once. It does not carry over to a later call, even one with the same code.
* **Fail closed.** When anything does not match, the run does not happen, and the model is told it was not approved.

## Building a Coding Agent

A coding agent works on a project, so even its smallest sandbox reads it. Start from a sandbox that reads the project and starts there, and widen it by subclassing:

```ruby
PROJECT = Rails.root.join("storage/workspace")

class ProjectSandbox < MXC::Sandbox
  directory PROJECT
  readable PROJECT
  timeout 300
end

class WorkspaceSandbox < ProjectSandbox
  writable PROJECT
end

class OnlineSandbox < ProjectSandbox
  network allow: ["rubygems.org", "pypi.org", "files.pythonhosted.org"]
end

class FullDiskSandbox < WorkspaceSandbox
  writable Dir.tmpdir
  network true
  timeout 600
end
```

A coding agent usually offers modes, such as ask before editing, edit freely, or skip permissions entirely. With sandboxes, each mode is only a choice of default and escalations. Switch modes by calling `with_code_execution` again:

```ruby
MODES = {
  ask: { sandbox: ProjectSandbox, escalate_to: [WorkspaceSandbox, OnlineSandbox] },
  workspace: { sandbox: WorkspaceSandbox, escalate_to: [OnlineSandbox] },
  dangerously_skip_permissions: { sandbox: FullDiskSandbox }
}.freeze

chat.with_code_execution(**MODES.fetch(:ask))
```

In `:ask`, the code reads the project and computes freely, and every edit or download waits for the user. In `:workspace`, it edits the project without asking, and only reaching the network asks. Skipping permissions means a wider default with nothing to ask for, and the code still runs in a sandbox: it never reaches what `FullDiskSandbox` leaves out.

A sandbox with a `directory` starts the code there, so each of these sees the project as its working directory. The run directory still exists: the conversation's files and the files to return are under `$RUN_DIR`, and the tool's description tells the model so.

## A Server Application

An application that runs code for its users, such as one that turns uploads into reports, needs one sandbox and no escalation. Give it a timeout and resource limits, and mount the folders the code reads:

```ruby
class ReportSandbox < MXC::Sandbox
  timeout 120
  limits cpu_time: 60, memory: 2.gigabytes
  priority :low
end

class ReportAgent < RubyLLM::Agent
  code_execution sandbox: ReportSandbox,
                 python: %w[pandas matplotlib],
                 mounts: -> { { "templates" => chat.account.templates_path } }
end
```

Without `escalate_to:`, the model has no way to ask for more, and no call waits for anyone.

`limits` caps the CPU time and memory each process the code starts may use, and `priority :low` keeps your application responsive while code runs. When the code uses up a limit, the sandbox stops it and the model is told which limit it hit. The limits apply to each process, so to bound a run that starts many workers, also limit the container your application runs in. See [mxc's limits on each platform](https://crmne.github.io/mxc/policies/#limits-on-each-platform) for what each platform enforces.

## Writing Your Own Sandbox

Any class or object with two methods can be a sandbox, such as one that runs code on a hosted service:

```ruby
class RemoteSandbox
  def supported?
    true
  end

  def run(*command, timeout:, readable: [], writable: [], denied: [], directory: nil, env: {}, network: nil)
    # Run the command and return an object answering
    # stdout, stderr, exit_code, and timed_out?
  end
end

RubyLLM.configure do |config|
  config.sandbox = "RemoteSandbox"
end
```

RubyLLM creates an instance of a class for each use. `run` takes the command like `Kernel#system`: one String runs through the shell, and several Strings are a program and its arguments. The keywords are what RubyLLM adds to the sandbox's own policy for one run:

| Keyword | Meaning |
| --- | --- |
| `readable` | Paths holding the run's files, the Ruby installation, and the declared packages |
| `writable` | The run directory and its home and temporary directories |
| `denied` | Paths the command must not see, even inside readable ones |
| `directory` | Where to start when the sandbox has no directory of its own |
| `env` | The environment the languages and packages need |
| `timeout` | The sandbox's own timeout, or 120 seconds |
| `network` | `nil` for the sandbox's own access; `{ allow: [...] }` only to install declared packages |

A sandbox on another machine copies the readable and writable paths in before the command runs and copies the writable ones back after it, so the files the code writes come back. Its result can also answer `blocked`, the hosts the network policy refused, which RubyLLM passes on to the model. To explain why `supported?` is false at boot, define `reason`, returning a String. Answer `readable`, `writable`, `network`, `directory`, `timeout`, and `limits` to describe the sandbox to the model and to the person approving an escalation.

## Next Steps

* [Code Execution]({% link _core_features/code-execution.md %}) - Let the model run Ruby, Python, JavaScript, and shell code.
* [Controlling Tool Execution]({% link _core_features/tool-execution.md %}) - Approve calls, remember approvals, and run calls concurrently.
* [Agents]({% link _advanced/agents.md %}) - Package code execution with instructions and tools.

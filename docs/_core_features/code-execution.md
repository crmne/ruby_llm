---
layout: default
title: Code Execution
parent: "Tools"
nav_order: 6
description: Let the model run Ruby, Python, JavaScript, and shell code in a sandbox on your own servers and hand back the files it makes.
---

# {{ page.title }}

{{ page.description }}
{: .fs-6 .fw-300 }

After reading this guide, you will know:

* How to let a chat or an agent run code.
* What the code can see, and what it cannot.
* How files go into a run and come back from it.
* How to give the code gems, Python and npm packages, and folders of your own.
* How the model asks to run a call in a wider sandbox.
* How to measure each run.

## Setting Up a Sandbox

A model that can run code can calculate exactly, transform data, and produce files such as charts, spreadsheets, and PDFs. That code was written by a model, so it never runs in your application's process. It runs in a [sandbox]({% link _core_features/sandboxes.md %}) that cannot read your project, your home directory, or your secrets.

Add the [mxc gem](https://crmne.github.io/mxc/), define a sandbox, and make it the default:

```ruby
# Gemfile
gem "mxc"
```

```ruby
# app/sandboxes/application_sandbox.rb
class ApplicationSandbox < MXC::Sandbox
  timeout 120
end
```

```ruby
# config/initializers/ruby_llm.rb
RubyLLM.configure do |config|
  config.sandbox = "ApplicationSandbox"
end
```

The sandbox decides what the code may read, write, and reach, and how long it runs. [Sandboxes]({% link _core_features/sandboxes.md %}) covers defining them, checking that they run on your servers, [what Linux needs]({% link _core_features/sandboxes.md %}#running-on-linux), and letting the model ask for a wider one.

## Running Code

Turn on code execution for a chat:

```ruby
chat = RubyLLM.chat.with_code_execution
chat.ask "What is the 200th Fibonacci number?"
```

The model gets one tool, `run_code`, that takes a language and a program. RubyLLM runs the program in the sandbox and sends the model its exit code, standard output, and standard error. The model can call it as many times as it needs, like any other [tool]({% link _core_features/tools.md %}).

`with_code_execution` follows the same shape as `with_thinking` and `with_caching`: call it bare to turn it on, pass options to tune it, and pass `false` to turn it off:

```ruby
chat.with_code_execution(languages: [:ruby, :python, :shell])
chat.with_code_execution(false)
chat.code_execution # => false
```

Calling `with_code_execution` without a configured sandbox raises `RubyLLM::ConfigurationError`. RubyLLM never falls back to running code outside a sandbox.

### Languages

The model writes Ruby or shell scripts by default. Choose from `:ruby`, `:python`, `:javascript`, and `:shell`:

```ruby
chat.with_code_execution(languages: [:python, :javascript])
```

Ruby is the one your application runs, without your application's gems or Bundler environment: Ruby's default and bundled gems load, and every other gem installed with it is hidden. JavaScript runs on the Node.js your application's `PATH` finds, wherever it is installed, including a version manager such as mise or nvm, and RubyLLM lets the sandbox read that installation. Python is whatever `python3` the sandbox finds on the system. The tool's description lists only the languages the sandbox can actually run, so the model never tries Python on a server without it.

### Timeouts and Network

Each run stops when its sandbox's timeout passes, after 120 seconds when the sandbox sets none. The sandbox stops the code and everything it started, and the model is told the run ran out of time. The code reaches the network only when its sandbox allows it. When it tries a host outside the sandbox's list, the request is refused and the model sees which hosts were blocked.

Both belong to the sandbox, so a chat that needs longer runs or a package registry uses a sandbox that allows them, as its default or [one call at a time](#asking-for-a-wider-sandbox).

### Following a Run

A run that builds a report or installs packages can take a while. While it runs, `run_code` reports the latest line of its output as [progress]({% link _core_features/tool-execution.md %}#reporting-progress), at most four times a second:

```ruby
chat.with_code_execution.after_tool_progress do |tool_call, progress|
  puts "#{tool_call.name}: #{progress.message}"
end
chat.ask "Count to five, one number a second"
# run_code: 1
# run_code: 2
# ...
```

Output streams only when something listens for progress, and the model still receives it when the run ends, within the usual [limits](#limits). A [sandbox of your own]({% link _core_features/sandboxes.md %}#writing-your-own-sandbox) reports progress when its `run` yields the output as it arrives.

## What the Code Can See

Each call gets a new, empty run directory, which RubyLLM removes when the call ends. The code starts there unless its sandbox sets a [directory of its own]({% link _core_features/sandboxes.md %}#building-a-coding-agent), and `RUN_DIR` holds its path either way. Nothing carries over from one call to the next, except files, which work like this:

* **Files in the conversation come in.** Every file attached to the conversation, and every file an earlier call returned, is copied into `attachments/` in the run directory, read-only. A file an earlier call returned keeps its path, so `out/chart.png` is at `attachments/out/chart.png`. A later file with the same path replaces an earlier one.
* **Files the code writes go out.** Every file the code writes in the run directory comes back as an attachment on the tool result message.

```ruby
chat = RubyLLM.chat.with_code_execution(python: %w[pandas matplotlib])
chat.ask "Plot monthly revenue from this export", with: "revenue.csv"

result = chat.messages.find(&:tool_result?)
result.attachments.first.filename # => "revenue.png"
```

In a chat with a [file store]({% link _core_features/chat-files.md %}), runs work with the chat's files instead, so the model reads a chart it drew with `read_file`, edits the script it wrote with `edit_file`, and runs it again. With a store in a folder, code runs in that folder and changes the files in place. With any other store, the model names the files its code reads in `run_code`'s `files` argument, they are copied into the run directory, and what the code writes is saved back. The tool result lists the paths instead of carrying the files. See [Code Execution]({% link _core_features/chat-files.md %}#code-execution) in the Chat Files guide.

```ruby
chat = RubyLLM.chat
  .with_file_store(RubyLLM.file_store.directory("tmp/work"))
  .with_code_execution(python: %w[pandas matplotlib])
chat.ask "Plot monthly revenue from this export", with: "revenue.csv"

chat.file_store.list.map(&:path) # => ["revenue.csv", "revenue.png"]
```

With a sandbox that grants nothing more, the code sees the system's programs and libraries read-only, its run directory, and nothing else: no project, no home directory, and no environment variables beyond `PATH`, `LANG`, `RUN_DIR`, and those the declared packages need. `HOME`, `XDG_CACHE_HOME`, and `TMPDIR` point to writable directories that live as long as the call, so programs such as LibreOffice and fontconfig can keep their profiles and caches.

### Your Own Folders

To give the code files of your own, such as report templates or brand assets, mount their directories with `mounts:`. Each key is where the directory appears in the run directory:

```ruby
chat.with_code_execution(mounts: { "templates" => Rails.root.join("app/templates/office") })
chat.ask "Write the quarterly report using templates/report.docx"
```

The code reads `templates/report.docx` but cannot change it, and the model's tool description lists the mounted folders. The keys are relative paths inside the run directory. `attachments/` and `skills/` are taken, and paths that leave the run directory raise ArgumentError.

When the folders depend on who is asking, pass a lambda. RubyLLM calls it before each run, and an empty Hash mounts nothing:

```ruby
chat.with_code_execution(mounts: -> { { "templates" => current_account.templates_path } })
```

### Other Programs

Programs installed under `/usr`, such as LibreOffice, Poppler's `pdftoppm`, and fontconfig, work without any setup. Grant read access to anything installed elsewhere in the sandbox:

```ruby
class ReadOnlySandbox < MXC::Sandbox
  readable "/opt/libreoffice", "/usr/share/fonts/custom"
  timeout 120
end
```

### Limits

| Limit | Value |
| --- | --- |
| Standard output and error sent to the model | 20,000 characters each, keeping the start and the end |
| Files returned per call | 10 |
| Size of a returned file | 10 MB |
| Text files the model reads back | 64 KB |

Files past the count or size limit stay out of the result, and the model is told which ones. Hidden files, symbolic links, and Python's `__pycache__` are never returned.

### What the Model Reads Back

The user gets every file. The model reads back images, PDFs, and text files up to 64 KB, so it can check the chart it drew. For larger text files and other formats, such as a spreadsheet or a ZIP archive, the model gets a short description that tells it where its code finds the file. The same applies to files a user attaches that the provider cannot read: with code execution on, the model is told to open them with code instead of the request failing.

## Packages

Declare the gems, Python packages, and npm packages the code can use:

```ruby
chat.with_code_execution(gems: %w[prawn rubyzip], python: %w[pandas matplotlib], npm: %w[pptxgenjs docx])
```

Declaring Python packages adds Python to the default languages, and declaring npm packages adds JavaScript. Pin versions the way each installer reads them: `"prawn:2.5.0"` for a gem, `"pandas==2.2.3"` for a Python package, and `"docx@9.5.1"` for an npm package. JavaScript finds npm packages with both `require` and `import`.

RubyLLM installs each set once, the first time a run needs it, and every later run mounts it read-only. The install runs in a sandbox too, one with none of your sandbox's access and only RubyGems (`rubygems.org`), PyPI (`pypi.org` and `files.pythonhosted.org`), or npm (`registry.npmjs.org`) reachable, so code that runs during installation is contained. npm packages install without running their install scripts, so packages that build native code at install time do not work. The code the model writes reaches only what its sandbox allows. Gems with native extensions need a compiler on the system.

Installed sets live in `config.package_cache_dir`, which defaults to a `packages` directory in your user cache directory. Each set is keyed by its packages and by the Ruby, Python, or Node.js that runs it, so upgrading Ruby installs it again. Processes that need the same set at the same time wait for one install instead of racing:

```ruby
RubyLLM.configure do |config|
  config.package_cache_dir = Rails.root.join("tmp/ruby_llm/packages").to_s
end
```

An install that fails raises `RubyLLM::Error` with the installer's output.

### Prebuilt Environments

To install packages when you build your image instead of at runtime, point code execution at the environment you built:

```ruby
chat.with_code_execution(gem_home: "/opt/sandbox/gems", virtualenv: "/opt/sandbox/venv",
                         node_modules: "/opt/sandbox/node/node_modules")
```

`gem_home:` takes a directory you installed gems into with `gem install --install-dir`, `virtualenv:` a Python virtualenv, and `node_modules:` the `node_modules` directory `npm install` created. RubyLLM mounts them read-only on every run and installs nothing. The tool's description lists the npm packages the `package.json` next to `node_modules` declares. Each replaces its declared counterpart, so pass `gems:` or `gem_home:`, `python:` or `virtualenv:`, and `npm:` or `node_modules:`, not both. A virtualenv adds Python to the default languages, and a `node_modules` adds JavaScript.

## Asking for a Wider Sandbox

List the sandboxes the model may ask for, and it can run one call at a time in one of them, with a reason, once someone approves it:

```ruby
chat = RubyLLM.chat.with_code_execution(sandbox: ReadOnlySandbox, escalate_to: [WorkspaceSandbox, OnlineSandbox])
chat.ask "Add a changelog entry for the new export feature"

chat.pending_approvals.first.arguments["sandbox"] # => "workspace"
chat.approve(chat.pending_approvals.first)
chat.complete
```

The next call runs in the default sandbox again, and an escalated call is never remembered. [Sandboxes]({% link _core_features/sandboxes.md %}#asking-for-a-wider-sandbox) covers approving these calls, why they are safe, and how to build a coding agent from them.

## Code Execution in Rails

Persisted chats run code the same way:

```ruby
chat = Chat.create!(model: "{{ site.models.default_chat }}").with_code_execution
chat.ask "Turn this export into a PDF report", with: params[:export]
```

The files a run returns are stored with Active Storage on the tool result message, like any other attachment, and later runs find them in `attachments/` after a reload or in another process. With `with_file_store`, they are saved to the chat's files in Active Storage instead. See [Chat Files]({% link _core_features/chat-files.md %}#files-in-rails).

## Agents

Agents declare code execution with the `code_execution` macro, which takes the same options:

```ruby
class AnalystAgent < RubyLLM::Agent
  instructions "Answer with numbers you computed, not estimates."
  code_execution python: %w[pandas]
end

class CodingAgent < RubyLLM::Agent
  code_execution sandbox: ReadOnlySandbox, escalate_to: [WorkspaceSandbox]
end
```

A `mounts:` lambda in an agent runs before each run with `chat` in scope, like the agent's other lambdas:

```ruby
class ReportAgent < RubyLLM::Agent
  code_execution mounts: -> { { "templates" => chat.account.templates_path } }
end
```

## Measuring Runs

Each run emits a `code_execution.ruby_llm` [instrumentation event]({% link _advanced/instrumentation.md %}) inside the run's `tool_call.ruby_llm` event:

```ruby
ActiveSupport::Notifications.subscribe("code_execution.ruby_llm") do |event|
  payload = event.payload
  Rails.logger.info(
    language: payload[:language],
    duration: payload[:duration],
    exit_code: payload[:exit_code],
    timed_out: payload[:timed_out]
  )
end
```

The payload carries the `chat`, the `tool_call_id` of the call it answers, the `language`, the `sandbox` it asked for (`nil` for the default), the `timeout` and `network` the run had, and, once it finishes, its `duration` in seconds, `exit_code`, `timed_out`, `blocked_hosts`, the `cpu_time` it used and the `limit_exceeded` it hit when its sandbox sets resource limits, and the `files` it returned. With [OpenTelemetry]({% link _advanced/opentelemetry.md %}) enabled, each run becomes a `ruby_llm.code_execution` span under its tool span.

## Running Code on the Provider's Servers

Some providers run code in their own hosted containers. Use [Provider Tools]({% link _core_features/provider-tools.md %}) for that:

```ruby
chat.with_provider_tools(:code_execution)
```

Hosted code execution needs no sandbox on your servers, but your files go to the provider and its containers decide what the code can reach.

## Next Steps

* [Sandboxes]({% link _core_features/sandboxes.md %}) - Define what the code can do, and let the model ask for more.
* [Tools]({% link _core_features/tools.md %}) - Write your own tools in Ruby.
* [Controlling Tool Execution]({% link _core_features/tool-execution.md %}) - Approve calls, run them concurrently, and watch them with callbacks.
* [Provider Tools]({% link _core_features/provider-tools.md %}) - Run code, search the web, and more on the provider's servers.
* [Agents]({% link _advanced/agents.md %}) - Package code execution with instructions and tools.

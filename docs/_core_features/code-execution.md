---
layout: default
title: Code Execution
parent: "Tools"
nav_order: 6
description: Let the model run Ruby, Python, and shell code in a sandbox on your own servers and hand back the files it makes.
---

# {{ page.title }}

{{ page.description }}
{: .fs-6 .fw-300 }

After reading this guide, you will know:

* How to configure a sandbox.
* How to let a chat or an agent run code.
* What the code can see, and what it cannot.
* How files go into a run and come back from it.
* How to give the code gems, Python packages, and other programs.
* How the model asks for network hosts and paths, and installs packages itself.
* How to measure each run.
* How to plug in a sandbox of your own.

## Setting Up a Sandbox

A model that can run code can calculate exactly, transform data, and produce files such as charts, spreadsheets, and PDFs. That code was written by a model, so it never runs in your application's process. It runs in a sandbox that cannot read your project, your home directory, or your secrets.

RubyLLM's built-in sandbox uses the [mxc gem](https://crmne.github.io/mxc/): Bubblewrap on Linux and Seatbelt on macOS. Code execution is verified on Linux and macOS. Add the gem and choose it in your configuration:

```ruby
# Gemfile
gem "mxc"
```

```ruby
RubyLLM.configure do |config|
  config.sandbox = :mxc
end
```

Without `config.sandbox`, nothing runs locally. Check that the sandbox works on this machine:

```ruby
RubyLLM.sandbox.supported? # => true
```

In Rails, RubyLLM checks this when the application boots and raises `RubyLLM::ConfigurationError` with the reason and how to fix it, so a server that cannot run code fails at deploy time instead of in the middle of a conversation. Build-time boots that set `SECRET_KEY_BASE_DUMMY`, such as `assets:precompile` in a Docker build, skip the check. See [Checking the Host](https://crmne.github.io/mxc/checking-the-host/) for what each platform needs.

## Running Code

Turn on code execution for a chat:

```ruby
chat = RubyLLM.chat.with_code_execution
chat.ask "What is the 200th Fibonacci number?"
```

The model gets one tool, `run_code`, that takes a language and a program. RubyLLM runs the program in the sandbox and sends the model its exit code, standard output, and standard error. The model can call it as many times as it needs, like any other [tool]({% link _core_features/tools.md %}).

`with_code_execution` follows the same shape as `with_thinking` and `with_caching`: call it bare to turn it on, pass options to tune it, and pass `false` to turn it off:

```ruby
chat.with_code_execution(languages: [:ruby, :python, :shell], timeout: 120)
chat.with_code_execution(false)
chat.code_execution # => false
```

Calling `with_code_execution` without a configured sandbox raises `RubyLLM::ConfigurationError`. RubyLLM never falls back to running code outside a sandbox.

### Languages

The model writes Ruby or shell scripts by default. Choose from `:ruby`, `:python`, and `:shell`:

```ruby
chat.with_code_execution(languages: [:python])
```

Ruby is the one your application runs, without your application's gems or Bundler environment: Ruby's default and bundled gems load, and every other gem installed with it is hidden. Python is whatever `python3` the sandbox finds on the system. The tool's description lists only the languages the sandbox can actually run, so the model never tries Python on a server without it.

### Timeouts

Each run stops after 120 seconds, long enough for work such as rendering a document with LibreOffice. Set your own limit with `timeout:`:

```ruby
chat.with_code_execution(timeout: 300)
```

When a run takes longer, the sandbox stops it and everything it started, and the model is told the run ran out of time.

The timeout is the only limit RubyLLM sets. Memory and CPU limits belong to the container or cgroup your application runs in, and runs inherit them.

### Network

The code has no network unless you grant it. Pass `true` for any destination, or list the hosts it may reach:

```ruby
chat.with_code_execution(network: { allow: ["api.github.com"] })
```

When the code tries to reach a host outside the list, the request is refused and the model sees which hosts were blocked. Host lists need extra packages on Linux and are not available on Windows; see [mxc's network policies](https://crmne.github.io/mxc/policies/#network).

To let the model ask for hosts as it needs them instead of listing them up front, give the chat a [permission mode](#asking-for-access).

## What the Code Can See

Each call starts in a new, empty working directory, which RubyLLM removes when the call ends. Nothing carries over from one call to the next, except files, which work like this:

* **Files in the conversation come in.** Every file attached to the conversation, and every file an earlier call returned, is copied into `attachments/` in the working directory, read-only. A later file with the same name replaces an earlier one.
* **Files the code writes go out.** Every file the code writes in the working directory comes back as an attachment on the tool result message.

```ruby
chat = RubyLLM.chat.with_code_execution(python: %w[pandas matplotlib])
chat.ask "Plot monthly revenue from this export", with: "revenue.csv"

result = chat.messages.find(&:tool_result?)
result.attachments.first.filename # => "revenue.png"
```

The code sees the system's programs and libraries read-only, its working directory, and nothing else: no project, no home directory, and no environment variables beyond `PATH`, `LANG`, and those the declared packages need. `HOME`, `XDG_CACHE_HOME`, and `TMPDIR` point to writable directories that live as long as the call, so programs such as LibreOffice and fontconfig can keep their profiles and caches.

### Your Own Folders

To give the code files of your own, such as report templates or brand assets, mount their directories with `mounts:`. Each key is where the directory appears in the working directory:

```ruby
chat.with_code_execution(mounts: { "templates" => Rails.root.join("app/templates/office") })
chat.ask "Write the quarterly report using templates/report.docx"
```

The code reads `templates/report.docx` but cannot change it, and the model's tool description lists the mounted folders. The keys are relative paths inside the working directory. `attachments/` and `skills/` are taken, and paths that leave the working directory raise ArgumentError.

When the folders depend on who is asking, pass a lambda. RubyLLM calls it before each run, and an empty Hash mounts nothing:

```ruby
chat.with_code_execution(mounts: -> { { "templates" => current_account.templates_path } })
```

### Other Programs

Programs installed under `/usr`, such as LibreOffice, Poppler's `pdftoppm`, and fontconfig, work without any setup. Grant read access to anything installed elsewhere with `readable:`:

```ruby
chat.with_code_execution(readable: ["/opt/libreoffice", "/usr/share/fonts/custom"])
```

The paths are read-only. Only your application and the user grant access: the model can [ask for more](#asking-for-access), but cannot widen what its code can see on its own.

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

## Gems and Python Packages

Declare the gems and Python packages the code can use:

```ruby
chat.with_code_execution(gems: %w[prawn rubyzip], python: %w[pandas matplotlib])
```

Declaring Python packages adds Python to the default languages. Pin versions the way each installer reads them: `"prawn:2.5.0"` for a gem, `"pandas==2.2.3"` for a package.

RubyLLM installs each set once, the first time a run needs it, and every later run mounts it read-only. The install runs in the sandbox too, with only RubyGems (`rubygems.org`) or PyPI (`pypi.org` and `files.pythonhosted.org`) reachable, so code that runs during installation is contained. The code the model writes stays offline. Gems with native extensions need a compiler on the system.

Installed sets live in `config.package_cache_dir`, which defaults to a `packages` directory in your user cache directory. Each set is keyed by its packages and by the Ruby or Python that runs it, so upgrading Ruby installs it again. Processes that need the same set at the same time wait for one install instead of racing:

```ruby
RubyLLM.configure do |config|
  config.package_cache_dir = Rails.root.join("tmp/ruby_llm/packages").to_s
end
```

An install that fails raises `RubyLLM::Error` with the installer's output.

### Prebuilt Environments

To install packages when you build your image instead of at runtime, point code execution at the environment you built:

```ruby
chat.with_code_execution(gem_home: "/opt/sandbox/gems", virtualenv: "/opt/sandbox/venv")
```

`gem_home:` takes a directory you installed gems into with `gem install --install-dir`, and `virtualenv:` a Python virtualenv. RubyLLM mounts them read-only on every run and installs nothing. Each replaces its declared counterpart, so pass `gems:` or `gem_home:`, and `python:` or `virtualenv:`, not both. A virtualenv adds Python to the default languages.

## Asking for Access

With a [permission mode]({% link _core_features/permissions.md %}), the model gets a second tool, `request_permission`. When a run is blocked, its result lists the blocked hosts and tells the model it can ask. The model names a network host, or a path to read or write, and says why:

```ruby
chat = RubyLLM.chat.with_code_execution.with_permissions(:ask)
chat.ask "Download the latest release notes from api.github.com and summarize them"

request = chat.pending_approvals.first
request.arguments # => {"permission"=>"network", "targets"=>["api.github.com"], "reason"=>"..."}

chat.approve(request)
chat.complete
```

Approving the request lets every later run in the chat reach exactly that host. `:auto` grants what its `allow:` list covers without asking, `:dangerous` grants everything, and `:read_only` denies every request. Without a permission mode, the model has no `request_permission` tool and its code gets only what you configured. [Permissions]({% link _core_features/permissions.md %}#asking-for-network-and-paths) covers paths and how grants work.

A granted writable path makes `run_code` a tool that changes things, so `:ask` asks before each run once you grant one.

### Packages the Model Installs

Once the model has a package registry, `rubygems.org` for gems or `pypi.org` and `files.pythonhosted.org` for Python packages, it can run `gem install` and `pip install`. The packages go into an environment kept for the chat, so its later runs find them, in this process and in any other:

```ruby
chat = RubyLLM.chat.with_code_execution(languages: [:python, :shell])
chat.with_permissions(:auto, allow: [{ network: ["pypi.org", "files.pythonhosted.org"] }])
chat.ask "Use requests to check which of these URLs respond", with: "urls.txt"
```

Each chat gets a GEM_HOME and, when Python is one of its languages, a virtualenv, under `chats/` in `config.package_cache_dir`. They see the gems and packages you declared, but not your application's gems. RubyLLM never removes them, so prune old ones with a scheduled job.

On Windows, mxc has no host lists, so a run with a granted host raises instead of opening the whole network.

Declared packages are installed once for every chat, and the model's code stays offline. Prefer them for what every conversation needs, and let the model install the rest.

## Code Execution in Rails

Persisted chats run code the same way:

```ruby
chat = Chat.create!(model: "{{ site.models.default_chat }}").with_code_execution
chat.ask "Turn this export into a PDF report", with: params[:export]
```

The files a run returns are stored with Active Storage on the tool result message, like any other attachment, and later runs find them in `attachments/` after a reload or in another process.

## Agents

Agents declare code execution with the `code_execution` macro, which takes the same options:

```ruby
class AnalystAgent < RubyLLM::Agent
  instructions "Answer with numbers you computed, not estimates."
  code_execution python: %w[pandas]
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

The payload carries the `chat`, the `tool_call_id` of the call it answers, the `language`, the `timeout` and `network` the run had, and, once it finishes, its `duration` in seconds, `exit_code`, `timed_out`, `blocked_hosts`, and the `files` it returned. With [OpenTelemetry]({% link _advanced/opentelemetry.md %}) enabled, each run becomes a `ruby_llm.code_execution` span under its tool span.

## Running Code on the Provider's Servers

Some providers run code in their own hosted containers. Use [Provider Tools]({% link _core_features/provider-tools.md %}) for that:

```ruby
chat.with_provider_tools(:code_execution)
```

Hosted code execution needs no sandbox on your servers, but your files go to the provider and its containers decide what the code can reach.

## Writing Your Own Sandbox

Any object with two methods can be the sandbox, such as one that runs code on a hosted service:

```ruby
class RemoteSandbox
  def supported?
    true
  end

  def run(*command, timeout:, readable: [], writable: [], denied: [], network: false, directory: nil, env: {})
    # Run the command and return an object answering
    # stdout, stderr, exit_code, and timed_out?
  end
end

RubyLLM.configure do |config|
  config.sandbox = RemoteSandbox.new
end
```

`run` takes the command like `Kernel#system`: one String runs through the shell, and several Strings are a program and its arguments. The keywords say what the command needs:

| Keyword | Meaning |
| --- | --- |
| `readable` | Paths on this machine the command may read |
| `writable` | Paths on this machine the command may read and change |
| `denied` | Paths the command must not see, even inside readable ones |
| `network` | `false`, `true`, or `{ allow: ["pypi.org"] }` |
| `timeout` | Seconds before the command is stopped |
| `directory` | The working directory |
| `env` | The only environment variables the command gets |

A sandbox on another machine copies the readable and writable paths in before the command runs and copies the writable ones back after it, so the files the code writes come back. Its result can also answer `blocked`, the hosts the network policy refused, which RubyLLM passes on to the model. To explain why `supported?` is false at boot, define `reason`, returning a String.

## Next Steps

* [Tools]({% link _core_features/tools.md %}) - Write your own tools in Ruby.
* [Controlling Tool Execution]({% link _core_features/tool-execution.md %}) - Approve calls, run them concurrently, and watch them with callbacks.
* [Provider Tools]({% link _core_features/provider-tools.md %}) - Run code, search the web, and more on the provider's servers.
* [Agents]({% link _advanced/agents.md %}) - Package code execution with instructions and tools.

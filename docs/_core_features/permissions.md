---
layout: default
title: Permissions
parent: "Tools"
nav_order: 7
description: Decide how much a model may do on its own, from read-only to fully autonomous, with one setting per chat.
---

# {{ page.title }}

{{ page.description }}
{: .fs-6 .fw-300 }

After reading this guide, you will know:

* How the four permission modes decide each tool call.
* How to mark tools that change nothing.
* How to let some tools and hosts through without asking.
* How to stop asking about a tool for the rest of a chat.
* How the model asks for network hosts and paths when it runs code.
* How the model installs gems and Python packages.
* How permissions persist in Rails and agents.

## Choosing a Mode

[`requires_approval`]({% link _core_features/tool-execution.md %}#requiring-approval) decides, tool by tool, which calls wait for a human. Often the decision belongs to the conversation instead: the same assistant browses freely in a support chat, asks before every change in an admin console, and runs unattended in a nightly job. Set a mode on the chat:

```ruby
chat = RubyLLM.chat.with_tools(SearchDocs, UpdateTicket)
chat.with_permissions(:ask)
chat.ask "Close every ticket about the login bug"

chat.awaiting_approval?                    # => true
chat.pending_approvals.map(&:name)         # => ["update_ticket", "update_ticket"]
```

The model searched on its own, because `SearchDocs` only reads. Each `update_ticket` call waits for `approve` or `deny`, exactly like a call to a tool declared with `requires_approval`, so an approval interface you already have works unchanged.

There are four modes:

| Mode | Read-only tools | Other tools | Sandbox requests |
| --- | --- | --- | --- |
| `:read_only` | Run | Denied | Denied |
| `:ask` | Run | Wait for approval | Wait for approval |
| `:auto` | Run | Run if in `allow:`, otherwise wait | Granted if in `allow:`, otherwise wait |
| `:dangerous` | Run | Run | Granted |

Sandbox requests come from [code execution](#asking-for-network-and-paths). A denied call never runs: the model receives a result saying it was not allowed, and the conversation continues.

Read the mode with `chat.permissions`, and remove it with `nil`:

```ruby
chat.permissions          # => :ask
chat.with_permissions(nil)
```

Without a mode, tools run unless they were declared with `requires_approval`, as they always have. A tool declared with `requires_approval` waits in every mode except `:dangerous`, so a tool you marked as needing a human always gets one unless you say otherwise.

`:dangerous` removes every approval, including those of `requires_approval` tools. It never removes the sandbox: code the model writes still runs where it cannot see your project or your secrets.

### Changing the Mode Mid-Chat

The mode applies from the next tool call, including calls that already wait for a decision. Switching a waiting chat to `:auto` with the tool allowed lets it through:

```ruby
chat.with_permissions(:auto, allow: [UpdateTicket])
chat.waiting? # => false
chat.complete
```

Switching to `:read_only` denies waiting calls, even ones you approved before the switch.

## Read-Only Tools

Mark a tool that changes nothing, such as a search or a lookup, with `read_only`:

```ruby
class SearchDocs < RubyLLM::Tool
  description "Searches the documentation"
  read_only

  def execute(query:)
    Docs.search(query)
  end
end
```

Read-only tools run in every mode. A tool that does not say so counts as one that can change things.

`read_only` and `requires_approval` answer different questions. `requires_approval` says a tool always needs a human, whatever the mode. `read_only` says a tool never changes anything, so a mode never needs to ask about it. Most tools declare neither:

| Tool | No mode | `:read_only` | `:ask` | `:auto` | `:dangerous` |
| --- | --- | --- | --- | --- | --- |
| `read_only` | Runs | Runs | Runs | Runs | Runs |
| Neither | Runs | Denied | Waits | Runs if in `allow:` | Runs |
| `requires_approval` | Waits | Denied | Waits | Waits | Runs |

[MCP]({% link _core_features/mcp.md %}) tools are read-only when their server marks them with the `readOnlyHint` annotation. That is the server's claim, so trust it as far as you trust the server.

`run_code`, the [code execution]({% link _core_features/code-execution.md %}) tool, counts as read-only: it changes nothing outside its sandbox. Once you grant it a writable path, it counts as a tool that changes things.

## Allowing Tools in `:auto`

`:auto` runs the tools you list and asks about the rest:

```ruby
chat.with_permissions(:auto, allow: [UpdateTicket, "send_reply", GitHub])
```

`allow:` takes Tool classes or instances, tool names, and MCP server classes or instances, which allow every tool of that server. It only works with `:auto`; passing it with another mode raises `ArgumentError`.

## Remembering an Approval

When the user approves a call and says "don't ask again", pass `remember: true`:

```ruby
chat.approve(tool_call, remember: true)
chat.complete
```

Later calls to the same tool run without asking for the rest of the chat. Remembered tools apply in `:ask` and `:auto`, and without a mode for tools declared with `requires_approval`. They never override `:read_only`.

## Asking for Network and Paths

With [code execution]({% link _core_features/code-execution.md %}) and a permission mode, the model gets a second tool, `request_permission`. When its code needs a host or a path the sandbox blocks, the model asks for it and says why:

```ruby
chat = RubyLLM.chat.with_code_execution(python: %w[pandas]).with_permissions(:ask)
chat.ask "Fetch the latest exchange rates and chart them"

request = chat.pending_approvals.first
request.name                    # => "request_permission"
request.arguments["permission"] # => "network"
request.arguments["targets"]    # => ["api.frankfurter.app"]
request.arguments["reason"]     # => "To download today's exchange rates"
```

The request is an ordinary tool call, so it shows up in `pending_approvals` like any other. Approve it, and every later `run_code` call in the chat can reach that host:

```ruby
chat.approve(request)
chat.complete
```

The model can ask for three kinds of access:

| Permission | Targets | Grants |
| --- | --- | --- |
| `network` | Host names, such as `pypi.org`, or `example.com:8443` for another port | Reaching those hosts |
| `readable` | Absolute paths that exist | Reading those files or directories |
| `writable` | Absolute paths that exist | Reading and changing them |

A grant covers exactly what the model named: no wildcards, no parent directories. RubyLLM resolves symbolic links, so the path you approve is the path that gets mounted, and refuses the root directory. A request it cannot accept, such as `*.example.com` or a relative path, gets an error back at once instead of waiting for you.

`approve(request, remember: true)` grants the same thing as `approve(request)`. It never turns into permission for every future request.

When a run is blocked, its result lists the blocked hosts and tells the model it can ask for them, so it asks instead of guessing.

In `:auto`, list the access the model may get without asking. A host may start with `*.` to cover its subdomains, and a path covers everything inside it. The grant is still for exactly what the model asked:

```ruby
chat.with_permissions(:auto, allow: [
  { network: ["pypi.org", "files.pythonhosted.org", "*.rubygems.org", "rubygems.org"] },
  { readable: ["/srv/datasets"] }
])
```

Host lists need extra packages on Linux and are not available on Windows, where a granted host makes the run raise instead of opening the whole network. See [mxc's network policies](https://crmne.github.io/mxc/policies/#network).

### Installing Packages

Once the model has a package registry, it can install what it needs:

```ruby
chat.with_permissions(:auto, allow: [{ network: ["pypi.org", "files.pythonhosted.org"] }])
chat.ask "Use requests to check which of these URLs are up", with: "urls.txt"
```

The model asks for the registry, then runs `pip install requests`, or `gem install` with `rubygems.org`. Packages go into an environment kept for the chat, a GEM_HOME and a Python virtualenv, so they stay installed for its later runs, in any process. RubyLLM keeps these environments in `config.package_cache_dir`, under `chats/`. Nothing removes them, so prune old ones with a scheduled job.

To give every chat the same packages, [declare them]({% link _core_features/code-execution.md %}#gems-and-python-packages) instead: RubyLLM installs them once, and the model never needs the network.

## Permissions in Rails

Persisted chats keep their mode in a `permissions` column and what they granted in a `permission_grants` column. The install generator creates both, and `bin/rails generate ruby_llm:upgrade` adds them to existing applications.

Every process reads them from the database, outside the query cache, before it decides a tool call. A user can switch the mode while a job runs, and the job applies it from its next tool call. An approval recorded in a request, with or without `remember: true`, takes effect in the job that resumes the chat:

```ruby
class ApprovalsController < ApplicationController
  def create
    chat = Chat.find(params[:chat_id])
    chat.approve(params[:tool_call_id], remember: params[:remember] == "1")
    CompleteJob.perform_later(chat.id)
  end
end
```

`allow:` names Ruby classes, so it is not stored. Load the chat through its agent, or set it again, in each process. A chat stored in `:auto` without an `allow:` list asks about everything that is not read-only.

Without the two columns, permission modes still work, but only in the process that set them.

## Agents

Agents declare the mode their chats start in:

```ruby
class SupportAgent < RubyLLM::Agent
  tools SearchDocs, UpdateTicket
  permissions :auto, allow: [UpdateTicket]
end
```

A chat that already has a mode keeps it. `SupportAgent.find(id)` restores the mode a persisted chat was switched to, and applies the agent's `allow:` list whenever that mode is `:auto`.

## Next Steps

* [Controlling Tool Execution]({% link _core_features/tool-execution.md %}) - Approve calls one at a time and watch them with callbacks.
* [Code Execution]({% link _core_features/code-execution.md %}) - Let the model run code in a sandbox.
* [Durable Agents]({% link _advanced/durable-agents.md %}) - Run approvals and resumes across jobs.

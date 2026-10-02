---
layout: default
title: MCP Client
parent: "Tools"
nav_order: 3
description: Connect your chats and agents to Model Context Protocol servers and use their tools, resources, and prompts
---

# {{ page.title }}

{{ page.description }}
{: .fs-6 .fw-300 }

After reading this guide, you will know:

* How to connect to an MCP server from a Ruby class.
* How to explore and call a server's tools from Ruby.
* How to choose, rename, wrap, and build on a server's tools.
* How to give a server's tools to chats, agents, and Rails records.
* How to read a server's resources and ask with its prompts.
* How to answer a server's requests for input and follow its progress and logs.
* How to keep up with servers whose tools and resources change.
* How to declare protocol extensions, host MCP Apps, and follow long tasks.
* How to authorize servers with OAuth.
* How RubyLLM talks to servers and keeps connections safe.

## Describing a Server

Services such as Linear, GitHub, Notion, and Dropbox expose their APIs as [Model Context Protocol](https://modelcontextprotocol.io) servers. RubyLLM is an MCP client: it connects to those servers and uses what they offer. It does not build MCP servers.

Describe a server you want to connect to in a subclass of `RubyLLM::MCP`, the way you describe a tool or an agent:

```ruby
class Linear < RubyLLM::MCP
  url "https://mcp.linear.app/mcp"
  bearer_token ENV.fetch("LINEAR_API_KEY")
end
```

`url` connects over Streamable HTTP. For a server that runs on your machine, give the command that starts it and RubyLLM talks to it over stdio:

```ruby
class Files < RubyLLM::MCP
  command "npx", "-y", "@modelcontextprotocol/server-filesystem", "."
  directory Rails.root
  env NODE_ENV: "production"
end
```

The process starts on the first request and stops when you call `close`.

### Custom Transports

Some servers are reached neither over HTTP nor over stdio, such as a server on a user's computer that dials out to your app through a tunnel. Give those a `transport`, an object that carries the JSON-RPC messages:

```ruby
class LaptopFiles < RubyLLM::MCP
  inputs :device
  transport { Tunnel.new(device) }
end
```

A transport responds to four methods:

```ruby
class Tunnel
  def request(message, version:, timeout: nil, headers: {})
    # Send the request and return the response as a Hash with string keys.
    # Yield notifications the server sends while it works, such as progress.
  end

  def notify(message, version:) = send_message(message)
  def cancel(notification, version:) = send_message(notification)
  def close = disconnect
end
```

The transport handles its own authentication and timeouts. `timeout` is `nil` unless RubyLLM wants a shorter one than the transport's own, and `headers` holds the tool arguments the server asks to receive as `Mcp-Param-*` HTTP headers, which a transport that doesn't end in HTTP can ignore. After `close`, the next request reconnects. Raise `RubyLLM::MCP::Error` when the server can't be reached. To let the model know instead, answer a `tools/call` request with a tool error, `{ "result" => { "isError" => true, "content" => [{ "type" => "text", "text" => "The laptop is offline" }] } }`.

To support [listening for changes](#listening-for-changes), a transport also responds to `listen(message, version:)`. It sends `message`, a `subscriptions/listen` request, yields each notification the server sends for it, and returns the server's response once the server ends the subscription. RubyLLM calls it from the listener's thread and raises `RubyLLM::CancelledError` there to stop it. For servers that predate the 2026-07-28 revision, `message` is `nil`, and the transport yields the changes the server announces on its own.

### Inputs

Most servers act on behalf of a user. Declare inputs, and settings that depend on them take a block or a method name:

```ruby
class Linear < RubyLLM::MCP
  url "https://mcp.linear.app/mcp"
  inputs :user
  bearer_token { user.linear_token }
  header "X-Workspace", :workspace_id

  private

  def workspace_id
    user.workspace.linear_id
  end
end

linear = Linear.new(user: current_user)
```

Blocks run on the instance whenever RubyLLM sends a request, so a token that refreshes is always current.

### Inline Servers

When a class is not worth writing, build a server with `RubyLLM.mcp`:

```ruby
docs = RubyLLM.mcp(url: "https://learn.microsoft.com/api/mcp")
files = RubyLLM.mcp(command: ["npx", "-y", "@modelcontextprotocol/server-filesystem", "."])
```

It takes the same settings as keywords: `transport:`, `bearer_token:`, `headers:`, `env:`, `directory:`, `timeout:`, `prefix:`, `input_requests:`, `log_level:`, `extensions:`, `oauth:`, and `name:`. That suits servers your users add at runtime:

```ruby
RubyLLM.mcp(url: server.endpoint, name: "mcp_#{server.id}", prefix: "mcp_#{server.id}",
            oauth: { owner: server })
```

A server with a `transport:` also needs a `name:`, since it has no URL or command to be named after.

## Exploring a Server

A server is a Ruby object. Open a console and ask it what it can do:

```ruby
>> docs = RubyLLM.mcp(url: "https://learn.microsoft.com/api/mcp")
>> docs.tools
=> [#<RubyLLM::MCP::Tool name: "microsoft_docs_search", read_only: true>, ...]
>> docs.tools.first.description
=> "Search official Microsoft/Azure documentation..."
>> docs.instructions
=> "..."
```

Every tool on the server is also a method, the way Active Record turns columns into attributes:

```ruby
result = docs.microsoft_docs_search(query: "Azure Blob Storage")
result.text        # => "..."
result.structured  # => { "results" => [...] }
result.attachments # => [#<RubyLLM::Attachment ...>]
result.meta        # => { "com.microsoft/request_id" => "..." }
```

Use `call` when a tool's name is not a valid Ruby method name:

```ruby
docs.call("microsoft_docs_search", query: "Azure Blob Storage")
```

A `RubyLLM::MCP::Result` has the text, any images or files as attachments, and the structured content when the server sends it. `error?` tells you whether the tool reported a failure. `meta` is the `_meta` Hash the server attached, in the vocabulary of whichever extension wrote it, and empty when there is none.

Each tool also carries the server's hints about its behavior: `read_only?`, `destructive?`, `idempotent?`, and `open_world?`. They come from the server, so trust them as far as you trust the server. A tool's `meta` is the `_meta` of its definition.

## Shaping Tools

A server hands the model every tool it has, often low-level ones written for any client. Decide what your model sees in the class.

### Choosing Tools

Keep the tools you need with `only`, or hide some with `except`:

```ruby
class GitHub < RubyLLM::MCP
  url "https://api.githubcopilot.com/mcp/"
  bearer_token ENV.fetch("GITHUB_TOKEN")
  only :search_issues, :get_issue, :create_issue
end
```

### Prefixing Names

Two servers can offer tools with the same name, such as `search`. Prefix one server's tools so both fit in a chat:

```ruby
class GitHub < RubyLLM::MCP
  url "https://api.githubcopilot.com/mcp/"
  prefix :github   # search_issues becomes github_search_issues
end
```

Tools you rename with `tool :x, as:` keep the name you gave them.

### Renaming and Describing

Give a tool the name and description that fit your agent:

```ruby
tool :search_issues, as: :search_ruby_llm_issues,
     description: "Search RubyLLM's issues. Use GitHub search syntax."
```

### Fixed Arguments

Take an argument away from the model and always send your value:

```ruby
tool :search_issues, fixed_arguments: { owner: "crmne", repo: "ruby_llm" }
```

The model sees `search_issues` without `owner` and `repo`, so it cannot search anywhere else. Use a lambda when a value depends on inputs: `fixed_arguments: { repo: -> { user.default_repo } }`.

### Wrapping Results

Name a method with `wrap:` to decide what the model sees. It receives the server's result and the arguments of the call:

```ruby
class GoogleDrive < RubyLLM::MCP
  url "https://drivemcp.googleapis.com/mcp/v1"
  inputs :user
  bearer_token { user.google_token }

  tool :read_file, as: :drive_read, wrap: :cite

  private

  def cite(result, file_id:)
    RubyLLM::SearchResults.new(title: file_id, url: "https://drive.google.com/open?id=#{file_id}",
                               text: result.text)
  end
end
```

The method runs on the MCP instance, so inputs like `user` are available. A result the server marks as an error goes to the model as an error without passing through the method.

### Adding Your Own Tools

Build higher-level tools from the server's primitives with a regular `RubyLLM::Tool`. When its `initialize` takes an argument, it receives the MCP. In a Rails app, it can live next to the server in `app/mcp/dropbox/search_and_read.rb`:

```ruby
class Dropbox::SearchAndRead < RubyLLM::Tool
  description "Search Dropbox and read the best match"
  parameter :query, description: "What to look for"

  def initialize(dropbox)
    @dropbox = dropbox
  end

  def execute(query:)
    match = @dropbox.search(query:, max_results: 1).structured["matches"].first
    return "Nothing found" unless match

    @dropbox.get_file_content(path_or_file_id: match["file_id"]).text
  end
end
```

Add it to the server in `app/mcp/dropbox.rb`:

```ruby
class Dropbox < RubyLLM::MCP
  url "https://mcp.dropbox.com/mcp"
  inputs :user
  bearer_token { user.dropbox_token }

  only :search
  tool SearchAndRead
end
```

The server's tools stay callable as methods even when `only` hides them from the model.

### Requiring Approval

Pause tools for a human decision with `requires_approval`. It uses the same flow as [tools that require approval]({% link _core_features/tool-execution.md %}#requiring-approval), including persisted decisions in Rails:

```ruby
requires_approval :create_issue, :merge_pull_request
requires_approval if: :destructive?
requires_approval if: ->(tool) { tool.name.start_with?("delete") }
```

Without names, every tool needs approval. `if:` takes a tool predicate or a lambda that receives the tool.

Every name you declare must exist on the server. When a server stops offering one, RubyLLM raises `RubyLLM::ConfigurationError` as the tools load, instead of silently changing what the model sees.

## Using Servers in Chats

Connect servers to a chat with `with_mcp`, and the model can call their tools:

```ruby
chat = RubyLLM.chat.with_mcp(Linear.new(user: current_user), Files)
chat.ask "Which open issues mention the flaky login spec?"
```

`with_mcp` accepts instances and classes. RubyLLM contacts a server the first time the chat needs its tools, so building a chat stays fast. Read connected servers by name, and pass `nil` to disconnect them:

```ruby
chat.mcp.linear   # => #<Linear ...>
chat.mcp[:files]  # => #<Files ...>
chat.with_mcp(nil)
```

Two tools with the same name raise an `ArgumentError` when the chat collects its tools.

### Agents

Agents declare servers with `mcp`. A block runs when the chat is built, with the agent's inputs available:

```ruby
class TriageAgent < RubyLLM::Agent
  inputs :user
  instructions "Triage incoming bug reports."
  mcp { [Linear.new(user: user), Files] }
end

TriageAgent.chat(user: current_user).ask "Triage the new reports"
```

### Rails

Chat records respond to `with_mcp` and `mcp` like plain chats, and agents with a `chat_model` connect their servers to the records they create and find. Tool calls persist like any other tool call.

## Resources

Servers also offer resources: files, records, or any data they name with a URI. They are files as far as RubyLLM is concerned, so they go wherever attachments go:

```ruby
files.resources
# => [#<RubyLLM::MCP::Resource uri: "file:///project/README.md", name: "README.md", mime_type: "text/markdown">, ...]

readme = files.resource("file:///project/README.md")
readme.content          # => "# My Project..."
readme.save("README.md")

chat.ask "Summarize this", with: readme
```

Resources from `resources` are read from the server the first time you need their content. `content` is text for a text resource and bytes for a binary one, and `meta` is the `_meta` the server sent: a resource you read has the `_meta` of its contents, one from `resources` has the `_meta` of the listing.

Some servers describe families of resources with URI templates. Fill one in with keywords:

```ruby
files.resource_templates
# => [#<RubyLLM::MCP::ResourceTemplate uri: "file:///{+path}", name: "Project files">]

files.resource("file:///{+path}", path: "app/models/user.rb")
```

RubyLLM never fetches a resource's URI directly, even when it is an `https` link. Every read goes through the server.

## Prompts

Servers can offer prompts: messages the server writes, filled in with your arguments. Ask a chat with one:

```ruby
github.prompts
# => [#<RubyLLM::MCP::Prompt name: "code_review", arguments: [:code, :language]>]

chat.ask github.prompt(:code_review, code: diff, language: "Ruby")
```

A prompt can hold several turns, including assistant messages, and `ask` adds all of them before the model answers. Read them with `messages`.

Prompts are meant to be chosen by people, like slash commands. To help users fill in arguments, ask the server for suggestions. The first keyword is the value to complete; the rest give context:

```ruby
review = github.prompts.first
review.suggest(language: "ru")              # => ["ruby", "rust"]
files.resource_templates.first.suggest(path: "app/mo")
```

## Input Requests

A server can stop in the middle of a call to ask the user something: which environment to deploy to, or to visit a page and connect an account. Answer with `before_input_request`, a method name or a block that receives a `RubyLLM::MCP::InputRequest`:

```ruby
class Deploys < RubyLLM::MCP
  url "https://deploys.example.com/mcp"
  inputs :user
  before_input_request :answer_from_settings

  private

  def answer_from_settings(request)
    if request.url?
      request.decline
    else
      request.answer(environment: user.default_environment)
    end
  end
end
```

A form request describes what it asks for in `fields`, each with a `name`, `type`, `title`, `description`, `choices`, and `default`, and `required?`. Show each `default` in your form: the fields an answer leaves out take theirs. A URL request has a `url` for the user to visit; `answer` with no values means the user agreed to go. `decline` refuses either kind. RubyLLM then sends the answers and the server finishes the call.

In a chat, a request no callback answers pauses the tool call, the way [tools that require approval]({% link _core_features/tool-execution.md %}#requiring-approval) pause. Show the requests to the user, record their answers, and resume:

```ruby
chat.ask "Deploy the release branch"

chat.awaiting_input?                         # => true
request = chat.pending_inputs.first
request.message                              # => "Which environment?"
request.fields.first.choices                 # => ["staging", "production"]

chat.answer(request, environment: "staging") # or chat.decline(request)
chat.complete
```

`complete` resumes the call once all its requests are settled: RubyLLM sends the answers with the server's saved request state, and the server finishes. Until then the chat is `waiting?`, as it is while a call waits for approval. Calling a tool outside a chat raises `RubyLLM::MCP::InputRequiredError` instead, with the unanswered requests in `requests`.

A paused chat waits until someone answers. If your app has nowhere to show a kind of request, tell servers not to send it:

```ruby
class Deploys < RubyLLM::MCP
  url "https://deploys.example.com/mcp"
  input_requests :url
end
```

RubyLLM accepts form and URL requests by default. `input_requests :form` or `input_requests :url` keeps one kind, and `input_requests false` accepts none, so servers finish the call without asking or answer with an error that raises `RubyLLM::MCP::Error`. A server that asks for a kind you left out gets a decline. Inline servers take the same setting: `RubyLLM.mcp(url: server.endpoint, input_requests: false)`.

In Rails, the requests persist on the tool call, so a job can pause, a controller can record the user's answer, and another job can resume the call after a deploy or a restart. New applications get the `mcp_state` column from `ruby_llm:install`; applications that installed RubyLLM 2.0 add it with `bin/rails generate ruby_llm:upgrade`.

Servers never ask for passwords or tokens through forms; those go through URL requests, so they never pass through your application.

## Progress and Cancellation

Servers can report progress while they work. Register `after_progress` with a method name or a block. It runs on the MCP instance with a `RubyLLM::Progress`:

```ruby
class Deploys < RubyLLM::MCP
  url "https://deploys.example.com/mcp"
  inputs :chat
  after_progress :broadcast_progress

  private

  def broadcast_progress(progress)
    Turbo::StreamsChannel.broadcast_update_to chat, target: "status", html: progress.message
  end
end
```

`progress.value` only grows, `progress.total` is set when the server knows how much work there is, and `progress.fraction` gives the share done.

In a chat, the progress of a server tool call also reaches `after_tool_progress` with the tool call, the same way a Ruby tool's reports do:

```ruby
chat.with_mcp(Deploys.new(chat:)).after_tool_progress do |tool_call, progress|
  puts "#{tool_call.name}: #{progress.message}"
end
```

RubyLLM asks the server for progress only when an `after_progress` or `after_tool_progress` callback listens.

Servers can also write log messages while they work on a request. Ask for them with `log_level`, and RubyLLM writes the messages at that level and above to its logger, under the server's name:

```ruby
class Deploys < RubyLLM::MCP
  url "https://deploys.example.com/mcp"
  log_level :warning
end
```

The levels are the protocol's, from `:debug` through `:info`, `:notice`, `:warning`, `:error`, `:critical`, and `:alert` to `:emergency`. Without a level, servers send no log messages.

Cancelling a chat also stops the server call it is waiting on, with no threads involved. `chat.cancel`, or the persisted cancellation flag on a Rails chat record, takes effect at the next event the server streams. Over HTTP, RubyLLM closes the response stream, which is how the 2026-07-28 revision cancels a request; stdio servers and older HTTP servers receive a cancellation notice. A server that answers with a single response and no events cannot be interrupted, so it stops at the request timeout.

## Listening for Changes

A server's tools can change while you use it: a user connects another account, or the server adds tools when the model asks for them. Its resources change too, such as a file it serves.

When a server says its tools changed, RubyLLM forgets the list it fetched, so the next turn of a chat lists them again. Servers that predate the 2026-07-28 revision may say so while they answer any request, and RubyLLM follows them with no setup. Newer servers only tell clients that listen. RubyLLM also forgets the list when a server answers a call with an error because the tool is gone.

### Reacting to Changes

Register `after_change` to act on changes yourself. It takes a method name or a block, runs on the MCP instance, and receives what changed: `:tools`, `:prompts`, or `:resources` when one of the server's lists changes, the `RubyLLM::MCP::Resource` whose content changed, or the `RubyLLM::MCP::Task` whose status changed when you [listen to tasks](#tasks):

```ruby
class Handbook < RubyLLM::MCP
  url "https://handbook.example.com/mcp"
  after_change :announce

  private

  def announce(change)
    case change
    when :tools then puts "Tools now: #{tools.map(&:name).join(', ')}"
    when RubyLLM::MCP::Resource then puts "#{change.uri} now reads: #{change.content}"
    end
  end
end
```

The resource reads its new content from the server the first time you ask for it.

### Listening in the Background

Call `listen` to hear about changes as they happen, between requests too:

```ruby
handbook = Handbook.new.listen(resources: ["handbook://policies"])
```

`listen` asks the server for every list it announces changes to, for updates to the `resources` you pass, as URIs or as resources from `resources`, and for the status of the `tasks` you pass, as [Tasks](#tasks) describes. It returns once the server confirms, then listens in a thread of its own until you call `close`, while chats and requests go on as before. Calling `listen` again replaces the resources and tasks it listens to.

A server that announces no changes leaves `listen` nothing to do. When the server cannot be reached, or will not send updates for a resource or task you pass, `listen` raises `RubyLLM::MCP::Error`.

Callbacks for the changes a listener hears run in its thread, one at a time, so keep them short. They can call the server, as `tools` and `content` do above. An exception in one is logged, and listening goes on.

When the connection drops or the server ends the subscription, RubyLLM subscribes again after about a second, doubling the wait up to a minute while the server stays away. Changes made in between are lost, so once it is back, RubyLLM treats everything it listens to as changed: it lists tools again, and `after_change` runs for each list the server announces changes to, each resource, and each task, which it checks on first. Write callbacks that can run again for something that didn't change.

Older servers send their changes on their session's event stream, and RubyLLM subscribes to resources with `resources/subscribe`; over stdio, the listener shares the server's pipe with your requests. `listen` works the same either way.

### Running a Listener

A listener holds a connection and a thread for as long as it runs, so start one where something owns it, and close it there. Requests and jobs rarely need one, since an MCP built for them lists the server's tools fresh. When your app should react to changes as they happen, run the listener in a process of its own:

```ruby
# script/listen_to_handbook.rb
handbook = Handbook.new.listen(resources: ["handbook://policies"])

begin
  sleep
ensure
  handbook.close
end
```

```
# Procfile
handbook: bin/rails runner script/listen_to_handbook.rb
```

In Rails, callbacks run inside the executor, like a job, so they can use Active Record and enqueue work:

```ruby
class Handbook < RubyLLM::MCP
  url "https://handbook.example.com/mcp"
  bearer_token Rails.application.credentials.handbook_token
  after_change :reindex

  private

  def reindex(change)
    ReindexPolicyJob.perform_later(change.uri) if change.is_a?(RubyLLM::MCP::Resource)
  end
end
```

A forked process does not inherit the listener's thread. If forked workers should listen too, call `listen` after forking, such as in Puma's `on_worker_boot`.

## Extensions

Extensions add features to the protocol that a client and a server both opt into. Declare the ones your app supports with `extension`, the extension's name and its settings:

```ruby
class Deploys < RubyLLM::MCP
  url "https://deploys.example.com/mcp"
  extension "com.example/audit", level: "full"
end
```

An extension's name starts with its vendor's prefix, and its settings belong to the extension, so they go to the server as you write them. RubyLLM declares your extensions with every request, and in the handshake with servers that predate 2026-07-28. A server that doesn't know an extension ignores it.

Inline servers take `extensions:`, a name or a Hash of names to settings:

```ruby
RubyLLM.mcp(url: server.endpoint, extensions: { "com.example/audit" => { level: "full" } })
```

RubyLLM implements the official extensions it knows by name. Declare those with a Symbol. It also declares the authorization extensions your [OAuth settings](#without-a-user) use.

### MCP Apps

[MCP Apps](https://modelcontextprotocol.io/extensions/apps/overview) let a server ship a UI with its tools: an HTML page, such as a chart or a form, that your app shows next to a tool's results. Declare `:apps`, and the server lists the tools that come with one:

```ruby
class Weather < RubyLLM::MCP
  url "https://weather.example.com/mcp"
  inputs :user
  bearer_token { user.weather_token }
  extension :apps
end

weather = Weather.new(user: current_user)
forecast = weather.tools.find { |tool| tool.name == "get_forecast" }
forecast.ui_uri     # => "ui://weather/forecast"
forecast.visibility # => [:model, :app]
```

The UI is a resource. Read it like any other, with its content security policy in `meta`:

```ruby
view = weather.resource(forecast.ui_uri)
view.mime_type # => "text/html;profile=mcp-app"
view.content   # => "<!DOCTYPE html>..."
view.meta["ui"] # => { "csp" => { "connectDomains" => ["https://api.weather.example"] }, "prefersBorder" => true }
```

Rendering the UI is your app's job. Following the MCP Apps spec, it runs in a sandboxed iframe on an origin separate from your app, inside a second iframe whose content security policy you build from `meta["ui"]["csp"]`, and your page passes it the tool's arguments and result.

In a chat, the model calls a tool with a UI like any other tool, and sees its text. The UI needs more, such as the structured content, so the tool result message keeps the server's whole result as `mcp_result`. In Rails it persists on the tool call, so a UI renders the same after a reload. A controller can give your page everything it needs:

```ruby
class Weather::ViewsController < ApplicationController
  def show
    message = Message.where(chat: Current.user.chats).find(params[:message_id])
    result = message.mcp_result
    view = Weather.new(user: Current.user).resource(result.ui_uri)

    render json: {
      html: view.content,
      csp: view.meta.dig("ui", "csp"),
      input: message.parent_tool_call.arguments,
      result: result.to_h
    }
  end
end
```

Your page loads `html` into the sandbox, then sends the UI `input` and `result` as the spec's tool input and tool result notifications. `mcp_result` is `nil` for tools without a UI, whose results are only what the model saw, and for failed calls, whose content is `{ "error": ... }` as for any tool. New applications get the `mcp_result` column from `ruby_llm:install`; applications that installed RubyLLM 2.0 add it with `bin/rails generate ruby_llm:upgrade`.

Some tools exist only for their UI, such as the one behind a refresh button. Their `visibility` leaves out `:model`: `tools` lists them, and you can call them, but chats never offer them to the model, even when you pass them to `with_tools`.

When the UI calls a tool, your page sends the call to a controller, which makes it on the UI's behalf. Look the tool up by its name on the server, and refuse it unless its `visibility` includes `:app`:

```ruby
class Weather::ToolCallsController < ApplicationController
  def create
    weather = Weather.new(user: Current.user)
    tool = weather.tools.find { |tool| tool.server_name == params[:name] }
    return head :forbidden unless tool&.visibility&.include?(:app)

    arguments = params.fetch(:arguments, {}).permit!.to_h.symbolize_keys
    render json: weather.call(tool.server_name, **arguments).to_h
  end
end
```

`call` returns the whole result, and `to_h` is the result as the server sent it, content, structured content, and `_meta` included, which is what the UI expects.

### Tasks

Some tools take minutes, such as rendering a report or running a deploy. With the [Tasks extension](https://modelcontextprotocol.io/extensions/tasks/overview), a server answers such a call with a task and does the work in the background. Declare `:tasks`:

```ruby
class Reports < RubyLLM::MCP
  url "https://reports.example.com/mcp"
  extension :tasks
end
```

A chat never waits for a task. The tool call pauses, the way [tools that require approval]({% link _core_features/tool-execution.md %}#requiring-approval) and [input requests](#input-requests) do, and `complete` returns:

```ruby
chat = RubyLLM.chat.with_mcp(Reports)
chat.ask "Render the quarterly report"

chat.awaiting_tasks? # => true
task = chat.pending_tasks.first
task.status          # => :working
task.status_message  # => "Rendering page 3 of 12"
task.poll_interval   # => 5.0
```

Call `complete` again later. The chat is `waiting?` until then, as it is for approvals and input requests. `complete` checks on each task once, without waiting, and resumes the chat when they're done, so the model sees their results. In Rails, the task persists on its tool call, so one job can pause the chat and another can check on it, even after a deploy. Schedule the next check from the task's poll interval:

```ruby
class CheckTasksJob < ApplicationJob
  def perform(chat_id)
    chat = ReportsAgent.find(chat_id)
    chat.complete
    return unless chat.awaiting_tasks?

    wait = chat.pending_tasks.filter_map(&:poll_interval).min || 5
    CheckTasksJob.set(wait: wait.seconds).perform_later(chat_id)
  end
end
```

`refresh` checks on a task without resuming the chat, which suits a progress indicator. `done?`, `completed?`, `failed?`, and `cancelled?` tell where it stands, `result` is its `RubyLLM::MCP::Result` once it completes, and `expires_at` is when the server may forget it. Every check also reports the task's status message to `after_progress` and `after_tool_progress`.

Servers can also announce when the status of a task changes, so you check on it when there is news instead of on a schedule. Pass the tasks to [`listen`](#listening-in-the-background), and `after_change` receives each `RubyLLM::MCP::Task` as it stands, with its `result` once it completes:

```ruby
class Reports < RubyLLM::MCP
  url "https://reports.example.com/mcp"
  extension :tasks
  after_change { |change| ReportReadyJob.perform_later(change.id) if change.is_a?(RubyLLM::MCP::Task) && change.done? }
end

reports = Reports.new.listen(tasks: chat.pending_tasks)
```

A server decides whether it announces the status of a task, and servers that predate 2026-07-28 never do, so `listen` raises `RubyLLM::MCP::Error` for tasks it won't hear about. Checking with `complete` works either way.

A task that needs input pauses the chat on [input requests](#input-requests): answer them and call `complete`. A task that fails raises `RubyLLM::MCP::Error` from `complete`. Cancelling the chat cancels its tasks the next time it runs, so after `chat.cancel`, or the persisted flag on a Rails record, `complete` cancels them and raises `RubyLLM::CancelledError`. `task.cancel` asks the server right away; the server may still finish the task.

Outside a chat, `call` waits for the task of a tool you call directly, and `wait` waits for any task, both up to the server's `timeout`:

```ruby
reports.render_report(quarter: "Q3").text
task.wait.result
```

## Authorization

A server that belongs to a service your app already signs users into can take that token with `bearer_token`. For everything else, MCP servers use OAuth, and RubyLLM runs it for you:

```ruby
class Linear < RubyLLM::MCP
  url "https://mcp.linear.app/mcp"
  inputs :user
  oauth owner: :user
end
```

`owner:` names whose credentials these are, usually an input. RubyLLM finds the server's authorization server, registers itself when needed, and uses PKCE, as the MCP authorization spec requires. Send the user to authorize, then finish in the callback:

```ruby
class LinearConnectionsController < ApplicationController
  def new
    redirect_to linear.authorization_url(redirect_uri: callback_linear_connection_url), allow_other_host: true
  end

  def callback
    linear.authorize(params)
    redirect_to root_path, notice: "Linear is connected."
  end

  private

  def linear
    Linear.new(user: Current.user)
  end
end
```

From then on, every request carries the user's token, and RubyLLM refreshes it when it expires. Check `linear.authorized?` before showing a chat that needs it, and call `linear.deauthorize` to forget the credentials. `authorize` raises `RubyLLM::MCP::Error` when the callback does not belong to the authorization it started, such as a wrong `state` or another issuer.

Some servers, such as Slack's, only accept apps you registered with them. Pass that app's credentials:

```ruby
class Slack < RubyLLM::MCP
  url "https://mcp.slack.com/mcp"
  inputs :user
  oauth owner: :user, client_id: ENV["SLACK_CLIENT_ID"], client_secret: ENV["SLACK_CLIENT_SECRET"]
end
```

An app belongs to the authorization server you registered it with. RubyLLM remembers that server the first time it uses the app's credentials, and if the MCP server later names another one, it raises `RubyLLM::MCP::Error` instead of sending them there. Register an app with the new authorization server and pass its credentials.

Pass `scopes:` to ask for specific scopes instead of the ones the server suggests.

### Without a User

Background jobs and services often connect as your app rather than on behalf of a user. When the authorization server issued your app its own credentials, use the client credentials grant:

```ruby
class Reports < RubyLLM::MCP
  url "https://mcp.example.com/mcp"
  oauth grant: :client_credentials, client_id: ENV["REPORTS_CLIENT_ID"], client_secret: ENV["REPORTS_CLIENT_SECRET"]
end

Reports.new.tools
```

No one signs in. RubyLLM requests a token the first time the server asks for one, and a new one before it expires. When the authorization server refuses, the request raises `RubyLLM::UnauthorizedError` with its reason. Every request declares the [OAuth Client Credentials extension](https://modelcontextprotocol.io/extensions/auth/oauth-client-credentials), which servers that require it check.

Authorization servers that accept signed assertions let you register a public key instead of sharing a secret. Pass the private key, as a PEM string or an `OpenSSL::PKey`, and RubyLLM signs a short-lived assertion for each token request:

```ruby
oauth grant: :client_credentials, client_id: "reports", private_key: Rails.application.credentials.reports_private_key
```

`private_key:` works for any app you registered, including one your users authorize.

A workload that already holds a token from its platform, such as a Kubernetes service account token or a SPIFFE JWT, can present that token instead and needs no client of its own:

```ruby
class Reports < RubyLLM::MCP
  url "https://mcp.example.com/mcp"
  oauth assertion: -> { File.read("/var/run/secrets/tokens/mcp-token") }
end
```

RubyLLM presents the `assertion:` with the JWT bearer grant. A block or method name is read again for every token, since platforms rotate them. The authorization server decides which platforms and workloads it trusts.

### Enterprise Single Sign-On

When your users sign in to your app through their company's identity provider, such as Okta, the company can decide which MCP servers they reach, and they skip the authorization screens. Pass the identity provider and the ID token from the user's sign-in:

```ruby
class Wiki < RubyLLM::MCP
  url "https://wiki.example.com/mcp"
  inputs :user
  oauth owner: :user, client_id: ENV["WIKI_CLIENT_ID"], client_secret: ENV["WIKI_CLIENT_SECRET"],
        identity_provider: { issuer: "https://acme.okta.com", client_id: ENV["OKTA_CLIENT_ID"],
                             client_secret: ENV["OKTA_CLIENT_SECRET"], id_token: -> { user.okta_id_token } }
end
```

The outer `client_id:` and `client_secret:` are your app's registration with the server's authorization server, and the ones under `identity_provider:` are its registration with the identity provider. Like other settings, the values may be blocks or method names.

RubyLLM exchanges the ID token at the identity provider for a grant addressed to the server's authorization server, then exchanges that grant for a token. The identity provider's policy decides who reaches which servers, and a refusal raises `RubyLLM::UnauthorizedError`. Every new token needs a current ID token, so refresh it the way your sign-in does. Every request declares the [Enterprise-Managed Authorization extension](https://modelcontextprotocol.io/extensions/auth/enterprise-managed-authorization), which servers that require it check.

### Proof-of-Possession Tokens

Some servers only accept tokens bound to a key, so a token that leaks is useless without the key. When a server's challenge or metadata requires DPoP, RubyLLM binds new tokens to a key it creates, keeps the key with the credentials, and signs every token request and every request to the server with it. There is nothing to configure.

### Storing Credentials

In Rails, credentials live in the `ruby_llm_mcp_credentials` table, encrypted with [Active Record encryption](https://guides.rubyonrails.org/active_record_encryption.html). New applications get the table from `ruby_llm:install`; applications that installed RubyLLM 2.0 add it with the upgrade generator:

```bash
bin/rails generate ruby_llm:upgrade
bin/rails db:encryption:init   # if your app has no encryption keys yet
bin/rails db:migrate
```

Plain Ruby keeps credentials in memory. Set `config.mcp_credential_store` to an object with `read(key)`, `write(key, data, owner:)`, and `delete(key)` to keep them elsewhere.

Some authorization servers rotate refresh tokens and reject one that was used twice, so RubyLLM refreshes each grant in one place at a time. Threads take turns, and a worker that waited uses the token the first one received. In Rails, a row lock does the same across processes. A store of your own that several processes share should also respond to `synchronize(key)`, running the block while no other process holds that key.

### Client Registration

Authorization servers that support client ID metadata documents can identify your app by a URL instead of a registration. Serve the document from your app and point RubyLLM at it:

```ruby
RubyLLM.configure do |config|
  config.mcp_client_id = "https://app.example.com/oauth/client.json"
  config.mcp_client_name = "Example"
end
```

The document's `client_id` must be that exact URL, and its `redirect_uris` must list your callback. Without it, RubyLLM registers with servers that allow dynamic registration, once per authorization server and callback. When an authorization server forgets a registration and answers `invalid_client`, RubyLLM registers again the next time a user authorizes.

## Connections and Safety

RubyLLM speaks the 2026-07-28 revision of the protocol, where every request stands alone. For servers that predate it, back to 2024-11-05, RubyLLM falls back to the older handshake and declares nothing but extensions, so those servers never send requests back. Should one ask anyway, RubyLLM answers right away that it doesn't support the request, so the call goes on. When such a server ends its session, or its process exits, RubyLLM starts a new session and sends the request again, and `close` ends the session. Connecting to a server that speaks none of these revisions raises `RubyLLM::MCP::Error`.

A response stream can break before the answer arrives, such as when a proxy drops a long call. RubyLLM then sends the request again, as the 2026-07-28 revision requires. Older servers can resume the stream instead: RubyLLM waits as long as the server asks and reconnects from the last event it received. Either way it tries three times at most, then raises `RubyLLM::MCP::Error`.

Some defaults protect applications that connect to servers they do not control:

* Plain HTTP is only allowed for `localhost` and loopback addresses. Everything else needs HTTPS.
* Redirects are never followed.
* Request logs never include headers, so tokens stay out of your logs.

RubyLLM does not check where a hostname resolves. When your users add servers, connect through a [context]({% link _getting_started/configuration-connection.md %}#contexts-isolated-configurations) whose `faraday_adapter` decides which addresses the app may reach. The context's connection settings carry every request to the server and every OAuth request its authorization makes, while chats keep the global ones:

```ruby
mcp_context = RubyLLM.context { |config| config.faraday_adapter = PublicAddressesOnly }

mcp_context.mcp(url: server.endpoint, prefix: "mcp_#{server.id}", oauth: { owner: server })
Linear.new(user: current_user, context: mcp_context)
```

Requests use the configured `request_timeout`. Set `timeout` on a server to change it:

```ruby
class Linear < RubyLLM::MCP
  url "https://mcp.linear.app/mcp"
  timeout 30
end
```

A server that answers with a protocol error raises `RubyLLM::MCP::Error`, whose `code` is the JSON-RPC error code. A server that wants credentials raises `RubyLLM::UnauthorizedError`.

## Next Steps

* [Controlling Tool Execution]({% link _core_features/tool-execution.md %}) for approvals and concurrency
* [Provider Tools]({% link _core_features/provider-tools.md %}) for MCP servers the provider connects to
* [Agents]({% link _advanced/agents.md %}) for reusable chat configurations

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
* How to answer a server's requests for input and follow its progress.
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

It takes the same settings as keywords: `bearer_token:`, `headers:`, `env:`, `directory:`, `timeout:`, and `name:`.

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
```

Use `call` when a tool's name is not a valid Ruby method name:

```ruby
docs.call("microsoft_docs_search", query: "Azure Blob Storage")
```

A `RubyLLM::MCP::Result` has the text, any images or files as attachments, and the structured content when the server sends it. `error?` tells you whether the tool reported a failure.

Each tool also carries the server's hints about its behavior: `read_only?`, `destructive?`, `idempotent?`, and `open_world?`. They come from the server, so trust them as far as you trust the server.

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

Resources from `resources` are read from the server the first time you need their content.

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

A form request describes what it asks for in `fields`, each with a `name`, `type`, `title`, `description`, `choices`, and `default`, and `required?`. A URL request has a `url` for the user to visit; `answer` with no values means the user agreed to go. `decline` refuses either kind. RubyLLM then sends the answers and the server finishes the call.

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

`complete` resumes the call once all its requests are settled: RubyLLM sends the answers with the server's saved request state, and the server finishes. Calling a tool outside a chat raises `RubyLLM::MCP::InputRequiredError` instead, with the unanswered requests in `requests`.

In Rails, the requests persist on the tool call, so a job can pause, a controller can record the user's answer, and another job can resume the call after a deploy or a restart. New applications get the `pending_input` column from `ruby_llm:install`; applications that installed RubyLLM 2.0 add it with `bin/rails generate ruby_llm:upgrade`.

Servers never ask for passwords or tokens through forms; those go through URL requests, so they never pass through your application.

## Progress and Cancellation

Servers can report progress while they work. Register `after_progress` with a method name or a block. It runs on the MCP instance with a `RubyLLM::MCP::Progress`:

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

Cancelling a chat also stops the server call it is waiting on, with no threads involved. `chat.cancel`, or the persisted cancellation flag on a Rails chat record, takes effect at the next event the server streams. Over HTTP, RubyLLM closes the response stream, which is how the 2026-07-28 revision cancels a request; stdio servers and older HTTP servers receive a cancellation notice. A server that answers with a single response and no events cannot be interrupted, so it stops at the request timeout.

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

Pass `scopes:` to ask for specific scopes instead of the ones the server suggests.

### Storing Credentials

In Rails, credentials live in the `ruby_llm_mcp_credentials` table, encrypted with [Active Record encryption](https://guides.rubyonrails.org/active_record_encryption.html). New applications get the table from `ruby_llm:install`; applications that installed RubyLLM 2.0 add it with the upgrade generator:

```bash
bin/rails generate ruby_llm:upgrade
bin/rails db:encryption:init   # if your app has no encryption keys yet
bin/rails db:migrate
```

Plain Ruby keeps credentials in memory. Set `config.mcp_credential_store` to an object with `read(key)`, `write(key, data, owner:)`, and `delete(key)` to keep them elsewhere.

### Client Registration

Authorization servers that support client ID metadata documents can identify your app by a URL instead of a registration. Serve the document from your app and point RubyLLM at it:

```ruby
RubyLLM.configure do |config|
  config.mcp_client_id = "https://app.example.com/oauth/client.json"
  config.mcp_client_name = "Example"
end
```

The document's `client_id` must be that exact URL, and its `redirect_uris` must list your callback. Without it, RubyLLM registers with servers that allow dynamic registration, once per authorization server and callback.

## Connections and Safety

RubyLLM speaks the 2026-07-28 revision of the protocol, where every request stands alone. For servers that predate it, RubyLLM falls back to the older handshake without declaring client capabilities, so those servers never send requests back.

Some defaults protect applications that connect to servers they do not control:

* Plain HTTP is only allowed for `localhost` and loopback addresses. Everything else needs HTTPS.
* Redirects are never followed.
* Request logs never include headers, so tokens stay out of your logs.

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

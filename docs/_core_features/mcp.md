---
layout: default
title: MCP Servers
parent: "Tools"
nav_order: 3
description: Connect Model Context Protocol servers and give their tools to your chats and agents
---

# {{ page.title }}

{{ page.description }}
{: .fs-6 .fw-300 }

After reading this guide, you will know:

* How to describe an MCP server in a Ruby class.
* How to explore and call a server's tools from Ruby.
* How to give a server's tools to chats, agents, and Rails records.
* How RubyLLM talks to servers and keeps connections safe.

## Describing a Server

Services such as Linear, GitHub, Notion, and Dropbox expose their APIs as [Model Context Protocol](https://modelcontextprotocol.io) servers. Describe a server in a subclass of `RubyLLM::MCP`, the way you describe a tool or an agent:

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

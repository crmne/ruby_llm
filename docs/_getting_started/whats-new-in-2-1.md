---
layout: default
title: What's New in 2.1
nav_order: 4
description: Connect to MCP servers, ask typed judgments, and give agents their own configuration in RubyLLM 2.1.
---

# {{ page.title }}

{{ page.description }}
{: .fs-6 .fw-300 }

After reading this guide, you will know:

* What got faster, and how to keep connections open between calls.
* How to connect your chats and agents to MCP servers.
* How to show what a slow tool is doing while it runs.
* How to ask typed judgments with TypeSafe's Jev models.
* How to chat with open-weight models on Hetzner.
* How to build an agent's configuration from its inputs.
* How to keep RubyLLM's tables on a secondary database.
* How upgrades work from 2.1 on.

RubyLLM 2.1 does less work on every call, and brings an MCP client, typed judgments, and more control over where agents and records get their configuration. For everything that arrived in 2.0, see [What's New in 2.0]({% link _getting_started/whats-new-in-2-0.md %}).

## Faster by Default

Most of 2.1's speed comes without changing your code. Streams parse events with RubyLLM's own parser, append long text and reasoning in place, deduplicate the citations a provider repeats on every chunk in one pass, and compute the cost once, when the stream ends, instead of on every chunk. Requests pick their protocol once instead of once per message, derive tool names once, and parse a successful response once.

A reply no longer keeps the request it answered, so a long chat holds one copy of its history instead of one per reply. If you read that request, see [Read Requests Before They Are Sent]({% link _reference/upgrading.md %}#read-requests-before-they-are-sent). The model registry loads once when several threads reach it together, and Vertex AI calls share one OAuth token instead of fetching their own. Persisted chats rebuild from the rows they already loaded, with fewer queries in applications that predate `automatic_scope_inversing`, and download a stored file only when a request sends it.

These measurements compare 2.0.0 with 2.1 on the same machine. Providers answer from canned responses, so the times show RubyLLM's own work:

| Workload | 2.0 | 2.1 |
| --- | --- | --- |
| Stream 500 text deltas from Anthropic | 9.8 ms | 4.1 ms |
| Stream a 2 MB event that arrives in 16 KB pieces | 116 ms | 2.0 ms |
| Stream 500 Perplexity chunks that each cite 20 sources | 137 ms | 17 ms |
| Ask a Bedrock chat with 200 messages of history | 2.9 ms | 0.40 ms |
| Embed 100 texts and read the 2.4 MB response | 4.5 ms | 2.2 ms |
| Memory kept by a streamed 40-turn chat with a 256 KB image | 28 MB | 0.48 MB |
| Eight threads loading the model registry at once | 273 ms | 32 ms |
| Twenty Vertex AI calls with a service account key | 20 token requests | 1 token request |
| Rebuild a persisted 100-message chat | 11.4 ms | 6.8 ms |
| The same chat without `automatic_scope_inversing` | 58 queries | 8 queries |
| Check `awaiting_approval?` on a chat with ten 1 MB images | 10 downloads | none |

Two more speedups need you to opt in. Calls now share HTTP connections, so an adapter that keeps connections open lets every call after the first skip the TCP and TLS handshake. Use `:net_http_persistent` from the `faraday-net_http_persistent` gem with threads, as in Puma and Sidekiq, or `:async_http` from `async-http-faraday` inside an Async reactor, as in Falcon:

```ruby
RubyLLM.configure do |config|
  config.faraday_adapter = :net_http_persistent
end
```

Twenty calls to a local HTTPS server through `:net_http_persistent` took one handshake instead of twenty, and 0.4 ms each instead of 2.1 ms. Across a real network, each handshake you skip also saves its round trips. See [Connection Reuse]({% link _getting_started/configuration-connection.md %}#connection-reuse).

In Rails, [run the 2.1 upgrade]({% link _reference/upgrading.md %}#upgrade-the-rails-schema) so chats remember the provider uploads of their stored files. A chat loaded in another process then sends the provider's copy of a large file instead of downloading the file and uploading it again. Five turns of a chat with a 30 MB PDF, each in a new process, uploaded 150 MB with 2.0 and nothing with 2.1.

To measure on your own machine, clone RubyLLM and compare any version with your checkout. The [benchmarks](https://github.com/crmne/ruby_llm/tree/main/benchmarks) need no API keys or network access:

```sh
bundle exec rake "benchmark:compare[v2.0.0]"
```

The numbers above are medians from an AMD Ryzen 9 9900X running Ruby 4.0.7. Times vary from machine to machine; counts such as queries, downloads, and uploads do not.

## MCP Client

Services such as Linear, GitHub, Notion, Slack, and Dropbox expose their APIs as Model Context Protocol servers. RubyLLM now includes an MCP client. Describe the server you want to connect to in a class, the way you describe a tool or an agent:

```ruby
class Linear < RubyLLM::MCP
  url "https://mcp.linear.app/mcp"
  inputs :user
  oauth owner: :user

  only :list_issues, :get_issue, :create_issue
  requires_approval :create_issue
end

chat = RubyLLM.chat.with_mcp(Linear.new(user: current_user))
chat.ask "What's blocking the release?"
```

Every server tool is also a Ruby method, so you can explore a server from the console:

```ruby
docs = RubyLLM.mcp(url: "https://learn.microsoft.com/api/mcp")
docs.tools
docs.microsoft_docs_search(query: "Azure Blob Storage").text
```

You decide what the model sees. Rename and redescribe tools, fix arguments the model should not choose, pass results through your own method, or build higher-level tools from the server's primitives with a regular `RubyLLM::Tool`. Resources work as attachments, prompts work with `ask`, and a server's requests for input pause the chat the way tool approvals do, surviving restarts in Rails.

Servers change while you use them. When a server says its tools changed, the next turn of a chat sees the new list. Call `listen` to hear about changes as they happen, including updates to the resources and tasks you care about, and react with `after_change`:

```ruby
class Handbook < RubyLLM::MCP
  url "https://handbook.example.com/mcp"
  after_change { |change| ReindexPolicyJob.perform_later(change.uri) if change.is_a?(RubyLLM::MCP::Resource) }
end

Handbook.new.listen(resources: ["handbook://policies"])
```

See [Listening for Changes]({% link _core_features/mcp.md %}#listening-for-changes).

The client speaks the 2026-07-28 revision of the protocol and falls back for servers that predate it. OAuth follows the MCP authorization spec, and Rails keeps the credentials encrypted. Background jobs can connect as your app itself, with client credentials, a private key, or a workload identity token, and companies can authorize their people through their identity provider. Servers that require DPoP get tokens bound to a key.

Declare the protocol extensions your app supports with `extension`. RubyLLM implements two. With MCP Apps, tools come with a UI your app renders next to their results, and each tool call keeps the result its UI needs, so the UI renders again after a reload. With Tasks, a server runs a long tool call in the background while the chat pauses, the way it pauses for an approval, so no job waits for it:

```ruby
class Reports < RubyLLM::MCP
  url "https://reports.example.com/mcp"
  extension :apps
  extension :tasks
end
```

Tools, results, and resources also expose the `_meta` that extensions write, and `log_level` brings a server's log messages into your logs. See [MCP Client]({% link _core_features/mcp.md %}).

## Tool Progress

A tool that downloads a large file or reads a scanned document can take a while. It can now say what it is doing, and your app can show it before the result arrives:

```ruby
class ReadReport < RubyLLM::Tool
  def execute(url:)
    progress "Downloading #{File.basename(url)}"
    pages = Scanner.pages(url)
    pages.each_with_index.map do |page, index|
      progress "Reading page #{index + 1} of #{pages.size}", value: index + 1, total: pages.size
      page.text
    end.join("\n")
  end
end

chat.with_tools(ReadReport).after_tool_progress do |tool_call, progress|
  puts "#{tool_call.name}: #{progress.message}"
end
```

MCP server tools report their progress through the same callback. It works with concurrent tool execution, on agents, and on Rails chat records. See [Reporting Progress]({% link _core_features/tool-execution.md %}#reporting-progress).

## Typed Judgments

Define questions about your application data and read probabilities, choices, and scores:

```ruby
class TicketTriage < RubyLLM::Judge
  probability :urgent, "Does this need attention today?"

  choice :department, "Which team should handle this?" do
    billing "Payments and refunds"
    technical "Bugs and integrations"
    other "Everything else"
  end
end

judgment = TicketTriage.judge("Please refund the duplicate charge today.")
judgment.urgent.probability
judgment.department.choice
```

Judges use `config.default_judgment_model` unless you override the model. They accept structured input, reusable definitions, and runtime procs. Choice and score answers include full distributions and confidence so your application can choose how to act. See [Judgments]({% link _core_features/judgments.md %}).

TypeSafe joins the built-in providers, bringing the total to eighteen. Use its hosted Jev models or a [Jev-compatible local server]({% link _getting_started/configuration-providers.md %}#jev-compatible-apis) through the same judgment API. OpenAI's `{{ site.models.openai_judgment }}` answers the same questions through OpenAI Decisions, including questions about [images]({% link _core_features/judgments.md %}#images) passed with `with:`.

## Hetzner

Hetzner joins the built-in providers, bringing the total to nineteen. Its experimental Inference API serves open-weight models from Hetzner's data centers:

```ruby
RubyLLM.chat(model: "Qwen3.8-27B", provider: :hetzner).ask("Hello from Hetzner")
```

Set `hetzner_api_key` to a token from the Hetzner Console. See [Provider Setup]({% link _getting_started/configuration-providers.md %}#hetzner).

## Agent Configuration

An agent can now build its configuration for each chat from its inputs, so every tenant can bring its own credentials or endpoint. A `context` block without arguments runs when the chat is built:

```ruby
class SupportAgent < RubyLLM::Agent
  model "{{ site.models.default_chat }}", provider: :openai
  inputs :workspace

  context do
    RubyLLM.context { |config| config.openai_api_key = workspace.openai_api_key }
  end
end

SupportAgent.chat(workspace: current_workspace)
```

It works with `SupportAgent.chat` and with Rails-backed agents, where the block also sees the chat record. A block that takes the configuration, as before, still runs once when the class is defined. See [Configuration Contexts]({% link _advanced/agents.md %}#configuration-contexts).

## A Secondary Database for RubyLLM

RubyLLM's supporting records can share a secondary database with your chats and messages. Point them at the same connection:

```ruby
Rails.application.config.to_prepare do
  RubyLLM::ActiveRecord::Record.connection_specification_name =
    LlmRecord.connection_specification_name
end
```

See [Rails Advanced Configuration]({% link _advanced/rails-advanced-config.md %}).

## Upgrades, One Release at a Time

From 2.1 on, each release ships the upgrade from the release before it. `bin/rails generate ruby_llm:upgrade` in 2.1 adds the MCP credentials table, columns for tool calls waiting on input or a task and for the results MCP Apps render, and a table where chats remember the provider uploads of their stored files. Applications on 1.x upgrade to 2.0 first. See [Upgrading]({% link _reference/upgrading.md %}).

## Try 2.1

Install RubyLLM 2.1:

```sh
bundle add ruby_llm --version "~> 2.1.0"
```

Start with [Getting Started]({% link _getting_started/getting-started.md %}), or follow [Upgrading]({% link _reference/upgrading.md %}) to update a 2.0 application.

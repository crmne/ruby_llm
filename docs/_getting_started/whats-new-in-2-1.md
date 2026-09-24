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

* How to connect your chats and agents to MCP servers.
* How to show what a slow tool is doing while it runs.
* How to ask typed judgments with TypeSafe's Jev models.
* How to chat with open-weight models on Hetzner.
* How to build an agent's configuration from its inputs.
* How to keep RubyLLM's tables on a secondary database.
* How upgrades work from 2.1 on.

RubyLLM 2.1 brings an MCP client, typed judgments, and more control over where agents and records get their configuration. For everything that arrived in 2.0, see [What's New in 2.0]({% link _getting_started/whats-new-in-2-0.md %}).

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

The client speaks the 2026-07-28 revision of the protocol and falls back for servers that predate it. OAuth follows the MCP authorization spec, and Rails keeps the credentials encrypted. See [MCP Client]({% link _core_features/mcp.md %}).

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

TypeSafe joins the built-in providers, bringing the total to eighteen. Use its hosted Jev models or a [Jev-compatible local server]({% link _getting_started/configuration-providers.md %}#jev-compatible-apis) through the same judgment API.

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

From 2.1 on, each release ships the upgrade from the release before it. `bin/rails generate ruby_llm:upgrade` in 2.1 adds the MCP credentials table and a column for tool calls waiting on input. Applications on 1.x upgrade to 2.0 first. See [Upgrading]({% link _reference/upgrading.md %}).

## Try 2.1

Install RubyLLM 2.1:

```sh
bundle add ruby_llm --version "~> 2.1.0"
```

Start with [Getting Started]({% link _getting_started/getting-started.md %}), or follow [Upgrading]({% link _reference/upgrading.md %}) to update a 2.0 application.

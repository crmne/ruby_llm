---
layout: default
title: Tool Search
parent: "Tools"
nav_order: 5
description: Give a model hundreds of tools without sending them all, and let it search for the ones it needs.
redirect_from:
  - /guides/tool-search
---

# {{ page.title }}
{: .no_toc }

{{ page.description }}
{: .fs-6 .fw-300 }

## Table of contents
{: .no_toc .text-delta }

1. TOC
{:toc}

---

After reading this guide, you will know:

*   Why large tool sets need tool search.
*   How to defer the tools of an MCP server, a chat, an agent, or a tool class.
*   How to see which tools are deferred and which ones the model found.
*   Which providers search for tools, and what happens on the others.

## Why Defer Tools

Every tool a chat registers sends its name, description, and schema with every request. An MCP server like GitHub's offers dozens of tools, and connecting a few servers puts hundreds of definitions in front of the model before it reads your question. That costs input tokens on every turn, and models pick the right tool less often when they have to choose from a long list.

A deferred tool stays out of the model's context. The provider gives the model a search tool instead, and the model searches for what it needs: "weather" finds `weather_lookup`. The provider then loads the matching definitions, and the model calls them like any other tool. Your tools run the same way they always do.

## Deferring an MCP Server's Tools

MCP servers are where tool lists grow longest. Pass `defer: true` to `with_mcp`:

```ruby
chat = RubyLLM.chat(model: "{{ site.models.anthropic_current }}")
chat.with_mcp(GitHub.new(user: current_user), Linear.new(user: current_user), defer: true)

chat.ask "Which open issues mention the flaky login spec?"
```

To defer some of a server's tools every time you connect it, declare them in the class. Without names, `defer` defers every tool of the server:

```ruby
class GitHub < RubyLLM::MCP
  url "https://api.githubcopilot.com/mcp/"
  bearer_token ENV.fetch("GITHUB_TOKEN")

  defer :search_code, :list_workflows, :get_workflow_run
end
```

`defer: false` on `with_mcp` offers every tool of the server up front in one chat, whatever the class declares. Tool classes you add to a server with `tool` keep their own `defer`.

## Deferring Tools in a Chat

`with_tools` takes the same option:

```ruby
chat.with_tools(CurrentTime)
chat.with_tools(*Catalog.tools, defer: true)
```

`CurrentTime` stays in front of the model on every turn, and the catalog's tools wait to be found. Keep the tools a conversation almost always needs undeferred, so the model can call them without searching first.

A tool that should always wait to be found declares it in its class:

```ruby
class DeepResearch < RubyLLM::Tool
  description "Runs a multi-step web investigation"
  defer

  parameter :query, description: "What to investigate"

  def execute(query:)
    Research.run(query)
  end
end

chat.with_tools(DeepResearch)
chat.with_tools(DeepResearch, defer: false)
```

The second call registers it as an ordinary tool for that chat.

## Agents and Rails

Agents pass `defer:` from their `tools` and `mcp` macros:

```ruby
class SupportAgent < RubyLLM::Agent
  model "{{ site.models.anthropic_current }}"
  tools LookupAccount
  mcp Zendesk, Stripe, defer: true
end
```

Chat records respond to `with_tools` and `with_mcp` with `defer:`, and agents with a `chat_model` apply their deferred tools to the records they create and find. The search a model ran is part of its reply, so a persisted chat that keeps `raw_content` on its messages replays it on the next turn like any other reply.

## Reading Deferred Tools

`deferred_tools` returns the deferred tools, keyed by name like `tools`:

```ruby
chat.tools.keys           # => [:current_time, :search_issues, :create_issue, ...]
chat.deferred_tools.keys  # => [:search_issues, :create_issue, ...]
```

The search appears on the reply that ran it, in `server_tool_calls`, before the tool calls it made possible:

```ruby
response = chat.messages.find(&:tool_call?)
response.server_tool_calls.any?  # => true
response.tool_calls.values.map(&:name)  # => ["search_issues"]
```

A tool the model found stays found for the rest of the conversation. RubyLLM sends the same tool list on every turn, so a prompt cache that covers the tools keeps hitting.

## Choosing the Search Tool

RubyLLM adds the provider's default search tool. Anthropic also offers a regular-expression search. Enable it with `with_provider_tools`, and RubyLLM uses it instead of adding the default:

```ruby
chat.with_provider_tools({ type: "tool_search_tool_regex_20251119", name: "tool_search_tool_regex" })
```

See [Provider Tools]({% link _core_features/provider-tools.md %}) for how raw tool definitions work.

## Provider Support

RubyLLM defers tools wherever it speaks Anthropic's Messages API or OpenAI's Responses API, including Claude on Vertex AI. It does not check the model first: a model without tool search answers with the provider's error. Check the provider's documentation for the models that support it.

Other providers and protocols, such as Gemini and OpenAI's Chat Completions API, receive deferred tools as ordinary tools. The same code runs everywhere, and only the token savings depend on the provider.

When a chat switches to another model of the same provider, the tools the earlier model found stay found. Switching to another provider starts over: a model with tool search searches again, and one without it receives every tool.

## Next Steps

*   [Tools]({% link _core_features/tools.md %})
*   [Model Context Protocol]({% link _core_features/mcp.md %})
*   [Provider Tools]({% link _core_features/provider-tools.md %})
*   [Anthropic tool search](https://platform.claude.com/docs/en/agents-and-tools/tool-use/tool-search-tool)
*   [OpenAI tool search](https://developers.openai.com/api/docs/guides/tools-tool-search)

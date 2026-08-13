---
layout: default
title: Server Tools
parent: "Tools"
nav_order: 3
description: Let the provider run tools for you. Web search, code execution, and MCP servers with one API across providers.
---

# {{ page.title }}

{{ page.description }}
{: .fs-6 .fw-300 }

After reading this guide, you will know:

* How to enable provider-executed tools with `with_server_tools`
* How to pass tool options and use tools RubyLLM has no alias for
* How to read tool results, citations, and billing counters from responses
* How server tool turns persist and replay in Rails apps

## What are Server Tools?

Regular [tools]({% link _core_features/tools.md %}) run in your Ruby process: the model asks, your code answers. Server tools run on the provider's own infrastructure instead. The model searches the web, fetches pages, or executes code in a sandbox, all within a single API request, and the response arrives with the work already done.

Providers bill server tools per use, on top of token costs.

## Enabling Server Tools

Enable server tools with `with_server_tools`. Portable aliases cover the common tools on every supported provider:

```ruby
chat = RubyLLM.chat(model: "claude-sonnet-5")
              .with_server_tools(:web_search)

response = chat.ask "What is the latest stable Ruby version? Cite your source."
response.content   # => "Ruby 3.5.1 is the latest stable version..."
response.citations # => [#<RubyLLM::Citation url="https://www.ruby-lang.org/...">]
```

Enable several at once, or mix in your own function tools:

```ruby
chat.with_server_tools(:web_search, :code_execution)
chat.with_tools(Weather).with_server_tools(:web_search)
```

The aliases map to each provider's current tool versions:

| Alias | Anthropic | OpenAI (Responses) | Azure (Responses) | Gemini | xAI | DeepSeek (Responses) | OpenRouter |
|-------|-----------|--------------------|-------------------|--------|-----|----------------------|------------|
| `:web_search` | `web_search_20260318` | `web_search` | not offered | `google_search` | `web_search` | `web_search` | `openrouter:web_search` |
| `:web_fetch` / `:url_context` | `web_fetch_20260318` | not offered | not offered | `url_context` | not offered | not offered | `openrouter:web_fetch` |
| `:x_search` | not offered | not offered | not offered | not offered | `x_search` | not offered | not offered |
| `:code_execution` | `code_execution_20260521` | `code_interpreter` | `code_interpreter` | `code_execution` | `code_execution` | not offered | `openrouter:shell` |
| `:file_search` | not offered | `file_search` | `file_search` | `file_search` | `file_search` | not offered | not offered |
| `:image_generation` | not offered | `image_generation` | `image_generation` | not offered | `image_generation` | not offered | `openrouter:image_generation` |
| `:apply_patch` | not offered | not offered | not offered | not offered | not offered | `custom` (`apply_patch`) | not offered |
| `:mcp` | `mcp_toolset` + `mcp_servers` | `mcp` | `mcp` | not offered | `mcp` | not offered | not offered |

Asking for an alias the provider does not define raises `RubyLLM::UnsupportedServerToolError` naming the aliases it does.

xAI serves server tools on its Responses API, the default protocol for Grok models. DeepSeek serves them on its opt-in Responses API, so pass `protocol: :responses` when creating the chat. The same goes for Azure: deployments named after gpt-5.4+ models route to its Responses API automatically, everything else needs `protocol: :responses`.

OpenRouter runs its tools transparently: results surface as citations and usage counters rather than as `server_tool_calls` entries.

## Tool Options

Pass options in the provider's own vocabulary with the keyword form:

```ruby
chat.with_server_tools(web_search: { allowed_domains: ["ruby-lang.org"], max_uses: 3 })
```

RubyLLM merges the options into the tool definition and does not translate them, so anything in the provider's documentation works as written.

## Tools Without an Alias

A raw Hash passes through to the provider verbatim. This is the escape hatch that keeps you current when a provider ships a new tool, or when you want to pin an older tool version:

```ruby
chat.with_server_tools({ type: "tool_search_tool_regex_20251119", name: "tool_search" })
```

RubyLLM places the definition in the request correctly, parses whatever result blocks come back, and replays them in later turns. No gem update required.

## Reading Results

The tool steps the model ran come back on `server_tool_calls`:

```ruby
response = chat.with_server_tools(:web_search).ask "Who won the 2026 Ruby Prize?"

response.server_tool_calls.map(&:type)
# => ["server_tool_use", "web_search_tool_result"]

search = response.server_tool_calls.first
search.name   # => "web_search"
search.input  # => {"query" => "2026 Ruby Prize winner"}
```

Each `ServerToolCall` keeps the provider's block verbatim in `raw`, so nothing the provider returns is lost.

Search results feed the same [citations]({% link _core_features/citations.md %}) API as document citations. Per-use billing counters arrive on the token accounting:

```ruby
response.tokens.server_tool_use # => {"web_search_requests" => 2}
```

## Multi-Turn Conversations and Streaming

Providers require server tool blocks back verbatim in later turns, and RubyLLM handles that replay for you. Streaming works the same as any other chat, and the final message carries the same `server_tool_calls`.

Anthropic sometimes pauses a long tool-using turn with a `pause_turn` stop reason. RubyLLM continues the turn automatically and merges the segments, so you always see one complete response.

## MCP Servers

The `:mcp` alias connects a remote MCP server on providers that support the connector:

```ruby
chat = RubyLLM.chat(model: "claude-sonnet-5")
              .with_server_tools(mcp: { url: "https://mcp.example.com", name: "example" })
```

On Anthropic this fills both the `mcp_servers` parameter and the matching toolset entry, and sends the required beta header.

## Rails

Chats built with `acts_as_chat` accept `with_server_tools` like any other chat setting, and agents can declare them:

```ruby
class ResearchAgent < RubyLLM::Agent
  model "claude-sonnet-5"
  server_tools :web_search
end
```

To persist server tool turns, the messages table needs two JSON columns. New installs get them from the generator; existing apps add them with a migration:

```ruby
add_column :messages, :server_tool_calls, :json
add_column :messages, :raw_content, :json
```

Without the columns everything still works in memory, but a chat reloaded from the database cannot replay a server tool turn to Anthropic, which rejects conversations missing those blocks.

## Costs

Server tools bill per use, not per token. Current prices are on each provider's pricing page; the per-request counters in `tokens.server_tool_use` tell you what a response consumed.

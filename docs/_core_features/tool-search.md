---
layout: default
title: Tool Search
nav_order: 9
description: Keep large tool catalogs out of Claude's prompt prefix. Mark tools as deferred and let Anthropic's server-side tool-search primitive load them on demand.
redirect_from:
  - /guides/tool-search
---

# {{ page.title }}
{: .d-inline-block .no_toc }

New in 1.15
{: .label .label-green }

{{ page.description }}
{: .fs-6 .fw-300 }

## Table of contents
{: .no_toc .text-delta }

1. TOC
{:toc}

---

After reading this guide, you will know:

*   When deferred tool loading helps.
*   How to mark tools as deferred.
*   How Anthropic loads deferred tools at runtime.
*   How to observe which tools the model loaded.

## When to use it

When a `RubyLLM::Chat` is wired to many tools — especially across one or more MCP servers — every tool's full JSON Schema ships in the system-prompt prefix on every turn. Three real costs follow:

1. **Token bloat.** Hundreds of tools can add tens of thousands of tokens per request.
2. **Prompt-cache eviction.** Adding or removing tools changes the prefix and invalidates the cache.
3. **Selection accuracy.** Models choose worse tools when the menu is long.

This translates Anthropic's [tool search tool](https://platform.claude.com/docs/en/agents-and-tools/tool-use/tool-search-tool) feature: mark tools as `deferred` and RubyLLM forwards `defer_loading: true` to Anthropic's API, which hides the schemas from Claude until a server-side BM25 primitive loads the tools the conversation actually needs.

**This feature currently only supports Anthropic.** On other providers, `defer: true` is silently coerced to regular registration (a warning is logged once).

## Marking tools as deferred

### Per-class DSL

```ruby
class DeepResearchTool < RubyLLM::Tool
  description "Runs a multi-step web search..."
  deferred  # class-level DSL

  param :query, desc: "..."
  def execute(query:); ...; end
end
```

### Per-call, for bulk registration (MCP case)

```ruby
chat = RubyLLM.chat(model: "claude-sonnet-4-6")
chat.with_tools(*mcp_client.tools, defer: true)
```

Per-call `defer: true` overrides a non-deferred class; `defer: false` overrides a `deferred` class.

## How Claude loads deferred tools

On Anthropic, `defer: true` translates to two things in the request payload:

1. `defer_loading: true` on each deferred tool's function entry.
2. A `tool_search_tool_bm25_20251119` primitive appended to the tools array.

Claude then runs the search server-side, loads the matching tools via a `tool_reference` mechanism, and calls them directly. RubyLLM parses the `tool_search_tool_result` blocks and moves the referenced tools from `chat.tool_catalog.deferred_tools` into the active `chat.tools` so the next turn can dispatch them normally.

## Observing what was loaded

```ruby
chat.on_tool_search do |event|
  # event.query    # nil for Anthropic-native — Claude runs the search server-side
  # event.results  # Array of promoted tool name Symbols
  Rails.logger.info("tool_search loaded: #{event.results}")
end
```

Inspect state:

```ruby
chat.tool_catalog           # => #<RubyLLM::ToolCatalog deferred=42 loaded=3>
chat.tool_catalog.deferred_tools  # Hash of deferred tool name => Tool
chat.tool_catalog.loaded_tools    # Set of promoted tool name symbols
```

## Kill switch

```ruby
RubyLLM.configure do |c|
  c.tool_search_enabled = false  # default true
end
```

When false, `defer: true` is coerced to regular registration and a warning is logged once per chat.

## Non-Anthropic providers

On OpenAI, Gemini, and Bedrock, `defer: true` is ignored and a warning is logged once — the tool registers normally. A follow-up release may add client-side emulation for these providers.

## Further reading

*   [Anthropic tool search tool](https://platform.claude.com/docs/en/agents-and-tools/tool-use/tool-search-tool)
*   [Tools guide]({% link _core_features/tools.md %})

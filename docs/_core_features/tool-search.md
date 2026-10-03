---
layout: default
title: Tool Search
parent: "Tools"
nav_order: 5
description: Mark tools as deferred so the provider's tool search loads only the ones a conversation needs and large tool catalogs stay out of the model's context.
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

*   How to mark tools as deferred.
*   Which providers and models support tool search, and what happens elsewhere.

## Deferring tools

Every tool a chat registers ships its full schema on every request. With dozens of tools that costs tokens, invalidates the prompt cache whenever the set changes, and makes the model choose worse. A deferred tool stays out of the model's context until the provider's tool search finds it, and the model then calls it like any other tool.

Pass `defer: true` when registering tools:

```ruby
files = RubyLLM.mcp(command: ["npx", "-y", "@modelcontextprotocol/server-filesystem", "."])

chat = RubyLLM.chat(model: "{{ site.models.anthropic_current }}")
chat.with_tools(*files.tools, defer: true)
```

Or declare it on a tool that should always be deferred:

```ruby
class DeepResearch < RubyLLM::Tool
  description "Runs a multi-step web investigation"
  deferred

  parameter :query, description: "What to investigate"

  def execute(query:)
    # ...
  end
end

chat.with_tools(DeepResearch)
```

`defer: true` also defers tools that are not declared `deferred`, and `defer: false` registers a `deferred` tool as an ordinary one.

Agents take the same option:

```ruby
class Researcher < RubyLLM::Agent
  model "{{ site.models.anthropic_current }}"
  tools SearchDocs, LookupAccount, defer: true
end
```

## Provider support

| Provider | Models |
|----------|--------|
| Anthropic | Claude Haiku 4.5, Sonnet 4.5, Opus 4.5 and later |
| OpenAI | gpt-5.4 and later, through the Responses API |

Support is checked per model on every request. Elsewhere, including OpenAI's Chat Completions API, deferred tools go out as ordinary tools, so the same code runs on every provider.

When a chat switches to another model of the same provider that supports tool search, the tools the earlier model found stay found. Otherwise the earlier searches are not replayed: a model with tool search searches again, and one without it gets every tool up front.

## Further reading

*   [Anthropic tool search tool](https://platform.claude.com/docs/en/agents-and-tools/tool-use/tool-search-tool)
*   [OpenAI tool search](https://developers.openai.com/api/docs/guides/tools-tool-search)
*   [Tools guide]({% link _core_features/tools.md %})

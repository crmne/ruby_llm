---
layout: default
title: Overview
seo:
  title: Migrating to RubyLLM
nav_order: 0
description: Move to RubyLLM from another AI framework or client, with side-by-side code and an honest account of what each one does better.
permalink: /migrating-from/
redirect_from:
  - /migrate/
  - /compare/
  - /migrate/langchainrb/
---

# Migrating to RubyLLM

{{ page.description }}
{: .fs-6 .fw-300 }

After reading this guide, you will know:

* Which guide covers the framework or client you use today.
* What each guide shows you.
* Where to start with RubyLLM.

Each guide puts the same task side by side, with the other project's code taken from its own documentation at the version it names. It says what maps across, what RubyLLM adds, and when to stay where you are.

## Choosing a Guide

| Coming from | Language | Guide |
| --- | --- | --- |
| Vercel AI SDK | JavaScript and TypeScript | [Vercel AI SDK]({% link _compare/ai-sdk.md %}) |
| LangChain and LangGraph | Python | [LangChain and LangGraph]({% link _compare/langchain.md %}) |
| OpenAI Agents SDK | Python | [OpenAI Agents SDK]({% link _compare/openai-agents.md %}) |
| Pydantic AI | Python | [Pydantic AI]({% link _compare/pydantic-ai.md %}) |
| CrewAI | Python | [CrewAI]({% link _compare/crewai.md %}) |
| LlamaIndex | Python | [LlamaIndex]({% link _compare/llamaindex.md %}) |
| The official `openai` and `anthropic` gems | Ruby | [Official Ruby SDKs]({% link _compare/official-sdks.md %}) |
| `ruby-openai` | Ruby | [ruby-openai]({% link _compare/migrate-ruby-openai.md %}) |

The guides for other languages are about the framework as much as the language. If your application is already in Ruby, the Ruby guides move it one call site at a time.

## Next Steps

* [Getting Started]({% link _getting_started/getting-started.md %}): install RubyLLM and build a small support desk.
* [How RubyLLM Works]({% link _getting_started/overview.md %}): see how the pieces fit together.
* [Agents]({% link _getting_started/agents.md %}): define agents as classes and use them anywhere.

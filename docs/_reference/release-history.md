---
layout: default
title: Release History
nav_order: 7
has_children: true
description: Every RubyLLM release, newest first, with what each one brought and where to read about it.
---

# {{ page.title }}

{{ page.description }}
{: .fs-6 .fw-300 }

Each minor release has a guide that walks through what it added. The newest one also appears in Getting Started. Patch releases are listed on [GitHub Releases](https://github.com/crmne/ruby_llm/releases).

| Release | Date | Highlights |
| --- | --- | --- |
| [2.2]({% link _getting_started/whats-new-in-2-2.md %}) | In development | Code execution in a sandbox on your own servers, and persisted chats that run in one process at a time |
| [2.1]({% link _reference/whats-new-in-2-1.md %}) | October 8, 2026 | MCP client, typed judgments, evaluations, OpenTelemetry tracing, and faster calls by default |
| [2.0]({% link _reference/whats-new-in-2-0.md %}) | September 18, 2026 | Broader provider coverage, new AI operations, human approval, durable agents, and usage tracking |
| [1.x](https://rubyllm.com/v1/) | | The 1.x documentation |

To move an application from one release to the next, follow [Upgrading]({% link _reference/upgrading.md %}).

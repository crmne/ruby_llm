---
layout: default
title: RubyLLM Ecosystem
nav_order: 3
description: Extend RubyLLM with MCP servers, structured schemas, and community-built tools for production AI apps.
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

* What the Model Context Protocol (MCP) is and how ruby_llm-mcp brings it to Ruby
* How RubyLLM::Schema simplifies structured data definition for AI applications
* Where to find community projects and how to contribute your own

## RubyLLM::MCP

**Model Context Protocol Support for Ruby**

[RubyLLM::MCP](https://github.com/patvice/ruby_llm-mcp) brings the [Model Context Protocol](https://modelcontextprotocol.io/) to Ruby, enabling your applications to connect to MCP servers and use their tools, resources, and prompts as part of LLM conversations.

### What is MCP?

The Model Context Protocol is an open standard that allows AI applications to integrate with external data sources and tools. MCP servers can expose:

- **Tools**: Functions that LLMs can call to perform actions
- **Resources**: Structured data that can be included in conversations
- **Prompts**: Predefined prompt templates with parameters

### Key Features

- 🔌 Multiple transport types (HTTP streaming, STDIO, SSE)
- 🛠️ Automatic tool integration with RubyLLM
- 📄 Resource management for files and data
- 🎯 Prompt templates with arguments
- 🔄 Support for multiple simultaneous MCP connections

### Installation

```bash
gem install ruby_llm-mcp
```

For detailed documentation, examples, and usage guides, visit the [RubyLLM::MCP documentation](https://rubyllm-mcp.com/).

---

## RubyLLM::Schema

**Ruby DSL for JSON Schema Creation**

[RubyLLM::Schema](https://github.com/danielfriis/ruby_llm-schema) provides a clean, Rails-inspired DSL for creating JSON schemas. It's designed specifically for defining structured data schemas for LLM function calling and structured outputs.

### Why Use RubyLLM::Schema?

When working with LLMs, you often need to define precise data structures for:

- Structured output formats
- Function parameter schemas
- Data validation schemas
- API response formats

RubyLLM::Schema makes this easy with a familiar Ruby syntax.

### Key Features

- 📝 Rails-inspired DSL for intuitive schema creation
- 🎯 Full JSON Schema compatibility
- 🔧 Support for all primitive types, objects, and arrays
- 🔄 Union types with `any_of`
- 📦 Schema definitions and references for reusability

### Installation

```bash
gem install ruby_llm-schema
```

For detailed documentation and examples, visit the [RubyLLM::Schema repository](https://github.com/danielfriis/ruby_llm-schema).

## RubyLLM::Instrumentation

**ActiveSupport::Notifications instrumentation for RubyLLM**

[RubyLLM::Instrumentation](https://github.com/sinaptia/ruby_llm-instrumentation) is a Rails plugin that instruments RubyLLM events with the built-in [ActiveSupport::Notifications](https://api.rubyonrails.org/classes/ActiveSupport/Notifications.html) instrumentation API.

### Why instrumenting RubyLLM?

You might need to build custom monitoring, analytics, or logging from your RubyLLM calls (see below).

### Supported events

- `complete_chat.ruby_llm`: Triggered when `RubyLLM::Chat#ask` is called.
- `execute_tool.ruby_llm`: Triggered when a tool call is executed.
- `embed_text.ruby_llm`: Triggered when `RubyLLM::Embedding.embed` is called.
- `paint_image.ruby_llm`: Triggered when `RubyLLM::Image.paint` is called.
- `moderate_text.ruby_llm`: Triggered when `RubyLLM::Moderation.moderate` is called.
- `transcribe_audio.ruby_llm`: Triggered when `RubyLLM::Transcription.transcribe` is called.

### Installation

```bash
gem install ruby_llm-instrumentation
```

For detailed documentation and examples, visit the [RubyLLM::Instrumentation repository](https://github.com/sinaptia/ruby_llm-instrumentation).

## RubyLLM::Monitoring

**RubyLLM monitoring within your Rails application**

[RubyLLM::Monitoring](https://github.com/sinaptia/ruby_llm-monitoring) is a Rails engine that provides a dashboard where you can see cost, throughput, response time, and error aggregations. On top of it, you can set up alerts so that when something interesting to you happens, you receive an email or a Slack notification.

### Features

- Captures events with RubyLLM::Instrumentation
- Dashboard with metrics: cost, throughput, response time, error rate
- Alert system: configurable, rule-based

### Installation

```bash
gem install ruby_llm-monitoring
```

For detailed documentation and examples, visit the [RubyLLM::Monitoring repository](https://github.com/sinaptia/ruby_llm-monitoring).

---

## Community Projects

The RubyLLM ecosystem is growing! If you've built a library or tool that extends RubyLLM, we'd love to hear about it. Consider:

- Opening a PR to add your project to this page
- Sharing it in our GitHub Discussions
- Using the `ruby-llm` topic on your GitHub repository

Together, we're building a comprehensive ecosystem for LLM-powered Ruby applications.
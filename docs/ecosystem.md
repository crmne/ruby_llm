---
layout: default
title: Ecosystem
nav_order: 4
permalink: /ecosystem
---

# Ecosystem
{: .no_toc }

The RubyLLM ecosystem includes complementary libraries that extend the core functionality to support advanced use cases like Model Context Protocol (MCP) integration and structured data schemas.
{: .fs-6 .fw-300 }

## Table of contents
{: .no_toc .text-delta }

1. TOC
{:toc}

---

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

---

## Community Projects

The RubyLLM ecosystem is growing! If you've built a library or tool that extends RubyLLM, we'd love to hear about it. Consider:

- Opening a PR to add your project to this page
- Sharing it in our GitHub Discussions
- Using the `ruby_llm` topic on your GitHub repository

Together, we're building a comprehensive ecosystem for LLM-powered Ruby applications.
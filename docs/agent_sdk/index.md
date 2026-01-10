---
layout: default
title: Agent SDK
nav_order: 7
has_children: true
permalink: /agent-sdk/
---

# Agent SDK

Build production AI agents with Claude Code as a Ruby library.

{: .new }
The Agent SDK wraps the Claude Code CLI, giving you the same tools, agent loop, and context management that power Claude Code - all from Ruby.

## Quick Example

```ruby
require 'ruby_llm'

# Find and fix a bug autonomously
RubyLLM::AgentSDK.query("Find and fix the bug in auth.rb") do |message|
  puts message.content if message.assistant?
end
```

The Agent SDK includes built-in tools for reading files, running commands, and editing code, so your agent can start working immediately without you implementing tool execution.

## Key Features

| Feature | Description |
|---------|-------------|
| **Built-in Tools** | Read, Write, Edit, Bash, Glob, Grep, WebSearch, and 10+ more |
| **Hooks** | Run custom code at key points in the agent lifecycle |
| **MCP Support** | Connect to external systems via Model Context Protocol |
| **Sessions** | Maintain context across multiple exchanges |
| **Permissions** | Control exactly which tools your agent can use |
| **Structured Output** | Extract JSON data with schema validation |
| **Rails Integration** | Background jobs, Turbo Streams, ActiveRecord persistence |

## Installation

Add to your Gemfile:

```ruby
gem 'ruby_llm'
```

Ensure Claude Code CLI is installed:

```bash
# macOS/Linux
curl -fsSL https://claude.ai/install.sh | bash

# or via Homebrew
brew install --cask claude-code

# or via npm
npm install -g @anthropic-ai/claude-code
```

Set your API key:

```bash
export ANTHROPIC_API_KEY=your-api-key
```

## Basic Usage

### One-off Query

```ruby
# Simple query with block - most common pattern
RubyLLM::AgentSDK.query("What files are in this directory?") do |message|
  case message.type
  when :assistant
    puts message.content
  when :result
    puts "Done! Cost: $#{message.total_cost_usd}"
  end
end
```

### Multi-turn Conversation

```ruby
# Client maintains session state automatically
client = RubyLLM::AgentSDK.client

client.query("Read the authentication module").each do |msg|
  puts msg.content if msg.assistant?
end

# Claude remembers context from previous query
client.query("Now find all places that call it").each do |msg|
  puts msg.content if msg.assistant?
end
```

### With Configuration

```ruby
# Pass options directly
RubyLLM::AgentSDK.query(
  "Refactor this codebase",
  model: "claude-sonnet-4-20250514",
  max_turns: 10,
  permission_mode: :accept_edits,
  allowed_tools: %w[Read Write Edit Glob Grep]
) do |message|
  puts message.content if message.assistant?
end

# Or use fluent builder pattern
client = RubyLLM::AgentSDK.client
  .with_model("claude-sonnet-4-20250514")
  .with_cwd("/path/to/project")
  .with_max_turns(10)
  .with_permission_mode(:accept_edits)
```

## Built-in Tools

Your agent can use these tools out of the box:

| Tool | Risk | What it does |
|------|------|--------------|
| **Read** | Low | Read any file in the working directory |
| **Glob** | Low | Find files by pattern (`**/*.rb`) |
| **Grep** | Low | Search file contents with regex |
| **LS** | Low | List directory contents |
| **WebSearch** | Low | Search the web for information |
| **WebFetch** | Low | Fetch and parse web pages |
| **AskUserQuestion** | Low | Ask clarifying questions |
| **TodoWrite** | Low | Track progress on tasks |
| **Write** | Medium | Create new files |
| **Edit** | Medium | Modify existing files |
| **NotebookEdit** | Medium | Edit Jupyter notebooks |
| **Bash** | High | Execute shell commands |
| **Agent** | High | Spawn subagents |

```ruby
# Read-only agent that can analyze but not modify
RubyLLM::AgentSDK.query(
  "Review this code for best practices",
  allowed_tools: %w[Read Glob Grep],
  permission_mode: :bypass_permissions
) do |message|
  puts message.content if message.result?
end
```

## Compare to RubyLLM::Chat

| Feature | Chat | Agent SDK |
|---------|------|-----------|
| **Interface** | Synchronous `ask` | Streaming Enumerator |
| **Tool execution** | You implement | Built-in (16+ tools) |
| **File operations** | Manual | Automatic |
| **Session management** | Manual | Automatic |
| **Permission control** | N/A | Fine-grained |
| **Best for** | Chat interfaces | Autonomous agents |

```ruby
# Chat: Simple question/answer, you handle tools
chat = RubyLLM.chat(model: 'claude-sonnet-4-20250514')
response = chat.ask("What is 2+2?")
puts response.content

# Agent SDK: Claude handles tools autonomously
RubyLLM::AgentSDK.query("Find and fix the bug") do |msg|
  puts msg.content if msg.assistant?
end
```

## Next Steps

- [Quickstart]({% link agent_sdk/quickstart.md %}) - Build your first agent in minutes
- [API Reference]({% link agent_sdk/api-reference.md %}) - Full API documentation
- [Rails Integration]({% link agent_sdk/rails.md %}) - Background jobs, Turbo, ActiveRecord
- [Hooks]({% link agent_sdk/hooks.md %}) - Custom code at lifecycle points
- [MCP]({% link agent_sdk/mcp.md %}) - Connect external systems
- [Sessions]({% link agent_sdk/sessions.md %}) - Multi-turn conversations
- [Permissions]({% link agent_sdk/permissions.md %}) - Control tool access
- [Structured Output]({% link agent_sdk/structured-output.md %}) - Extract JSON data
- [Examples]({% link agent_sdk/examples.md %}) - Real-world implementations

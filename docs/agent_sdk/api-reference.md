---
layout: default
title: API Reference
parent: Agent SDK
nav_order: 2
permalink: /agent-sdk/api-reference
---

# API Reference

Complete API documentation for the RubyLLM Agent SDK.

## Module Methods

### `AgentSDK.query`

The primary method for interacting with Claude Code. Streams messages as they arrive.

```ruby
RubyLLM::AgentSDK.query(prompt, **options) do |message|
  # Process each message
end

# Or without block - returns lazy Enumerator
messages = RubyLLM::AgentSDK.query(prompt, **options)
messages.each { |msg| puts msg.content }
```

**Parameters:**

| Parameter | Type | Description |
|-----------|------|-------------|
| `prompt` | String | The input prompt |
| `options` | Hash | Configuration options (see Options below) |

**Returns:** `Enumerator::Lazy<Message>` if no block given

### `AgentSDK.client`

Creates a stateful client for multi-turn conversations.

```ruby
client = RubyLLM::AgentSDK.client(**options)
client.query("First message").each { |msg| ... }
client.query("Follow-up").each { |msg| ... }  # Remembers context
```

**Returns:** `Client` instance

### `AgentSDK.tool`

Creates a custom tool definition for use with MCP servers.

```ruby
weather_tool = RubyLLM::AgentSDK.tool(
  name: "get_weather",
  description: "Get current weather for a location",
  input_schema: {
    location: { type: "string", description: "City name" }
  }
) { |args| "Sunny in #{args[:location]}" }
```

**Returns:** `Tool` instance

### `AgentSDK.create_sdk_mcp_server`

Creates an in-process MCP server with Ruby tools.

```ruby
server = RubyLLM::AgentSDK.create_sdk_mcp_server(tools: [weather_tool])
```

**Returns:** `MCP::Server` instance

### Introspection Methods

```ruby
# Check if CLI is available
RubyLLM::AgentSDK.cli_available?  # => true/false

# Get CLI version
RubyLLM::AgentSDK.cli_version  # => "1.0.0"

# Check all requirements
RubyLLM::AgentSDK.requirements_met?
# => { cli_available: true, cli_version: "1.0.0", oj_available: true }

# List built-in tools
RubyLLM::AgentSDK.builtin_tools
# => ["Agent", "AskUserQuestion", "Bash", "Edit", ...]

# List hook events
RubyLLM::AgentSDK.hook_events
# => [:pre_tool_use, :post_tool_use, ...]

# List permission modes
RubyLLM::AgentSDK.permission_modes
# => [:default, :accept_edits, :bypass_permissions, :plan]

# Get options schema
RubyLLM::AgentSDK.options_schema
# => { prompt: { type: String, required: true }, ... }
```

## Options

Configuration for `query()` and `client()`.

### Core Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `prompt` | String | required | The input prompt |
| `cwd` | String | `Dir.pwd` | Working directory |
| `model` | String | CLI default | Claude model to use |
| `fallback_model` | String | nil | Model to use if primary fails |
| `max_turns` | Integer | nil | Maximum conversation turns |
| `max_thinking_tokens` | Integer | nil | Maximum tokens for thinking |
| `max_budget_usd` | Float | nil | Maximum budget in USD |

### Permission Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `permission_mode` | Symbol | `:default` | Permission mode (see below) |
| `allow_dangerously_skip_permissions` | Boolean | false | Enable bypass mode |
| `allowed_tools` | Array | all | List of allowed tool names |
| `disallowed_tools` | Array | [] | List of disallowed tools |

**Permission Modes:**

| Mode | Description |
|------|-------------|
| `:default` | Standard permission behavior |
| `:accept_edits` | Auto-accept file edits |
| `:bypass_permissions` | Bypass all permission checks |
| `:plan` | Planning mode - no execution |

### Session Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `resume` | String | nil | Session ID to resume |
| `resume_session_at` | String | nil | Resume at specific message UUID |
| `fork_session` | Boolean | false | Fork to new session when resuming |
| `continue` | Boolean | false | Continue most recent conversation |

### System Prompt Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `system_prompt` | String/Hash | nil | Custom system prompt |

```ruby
# String form
system_prompt: "You are a helpful code reviewer."

# Preset form (uses Claude Code's system prompt)
system_prompt: { type: 'preset', preset: 'claude_code' }

# Preset with append
system_prompt: {
  type: 'preset',
  preset: 'claude_code',
  append: 'Focus on security issues.'
}
```

### MCP & Hooks Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `mcp_servers` | Hash | {} | MCP server configurations |
| `hooks` | Hash | {} | Hook callbacks for events |
| `can_use_tool` | Proc | nil | Custom permission function |

### Advanced Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `agents` | Hash | {} | Subagent definitions |
| `plugins` | Array | [] | Plugin configurations |
| `betas` | Array | [] | Beta features to enable |
| `sandbox` | Hash | nil | Sandbox configuration |
| `setting_sources` | Array | [] | Settings to load |
| `additional_directories` | Array | [] | Extra accessible directories |
| `include_partial_messages` | Boolean | false | Include streaming partials |
| `output_format` | Hash | nil | Structured output schema |
| `enable_file_checkpointing` | Boolean | false | Enable file rewind |
| `strict_mcp_config` | Boolean | false | Strict MCP validation |
| `env` | Hash | {} | Environment variables |
| `cli_path` | String | 'claude' | Path to CLI executable |
| `stderr` | Proc | nil | Callback for stderr |

### Using Options Object

```ruby
# Constructor kwargs (preferred)
options = RubyLLM::AgentSDK::Options.new(
  model: "claude-sonnet-4-20250514",
  cwd: "/path/to/project",
  max_turns: 5
)

# Fluent builder pattern
options = RubyLLM::AgentSDK::Options.new
  .with_model("claude-sonnet-4-20250514")
  .with_cwd("/path/to/project")
  .with_max_turns(5)
  .with_permission_mode(:accept_edits)
  .with_tools(:Read, :Edit, :Glob)
```

## Message Types

All messages returned by `query()` are `Message` instances.

### Type Predicates

```ruby
message.assistant?      # Assistant response
message.user?          # User message
message.result?        # Final result
message.system?        # System message
message.stream_event?  # Partial streaming message
message.partial?       # Alias for stream_event?
```

### Subtype Predicates

```ruby
# Result subtypes
message.success?                # Completed successfully
message.error?                  # Any error
message.error_max_turns?        # Hit turn limit
message.error_during_execution? # Runtime error
message.error_max_budget?       # Hit budget limit

# System subtypes
message.init?             # Session initialization
message.compact_boundary? # Conversation compacted
```

### Common Fields

```ruby
# All messages
message.type           # :assistant, :user, :result, :system, :stream_event
message.subtype        # Subtype symbol if applicable
message.uuid           # Unique message ID
message.session_id     # Session ID
message.parent_tool_use_id  # Parent tool use (for subagents)

# Content
message.content        # Text content
message.role          # :assistant, :user, etc.
message.message       # Raw message data

# Tool use
message.tool_use?     # Has tool use blocks?
message.tool_calls    # Array of tool calls
message.tool_use_blocks  # Normalized tool blocks
message.tool_name     # First tool name
message.tool_input    # First tool input
message.tool_use_id   # First tool use ID
```

### Result Message Fields

```ruby
message.duration_ms       # Total duration
message.duration_api_ms   # API call duration
message.num_turns         # Number of turns
message.total_cost_usd    # Total cost
message.usage            # Token usage stats
message.model_usage      # Per-model usage
message.permission_denials  # Denied operations
message.structured_output   # JSON output (if schema provided)
message.errors           # Error messages (if error)
```

### System Init Message Fields

```ruby
message.api_key_source   # Source of API key
message.cwd             # Working directory
message.tools           # Available tools
message.mcp_servers     # Connected MCP servers
message.model           # Model being used
message.permission_mode # Current permission mode
message.slash_commands  # Available commands
message.output_style    # Output style
```

## Client

Stateful client for multi-turn conversations.

```ruby
client = RubyLLM::AgentSDK.client(model: "claude-sonnet-4-20250514")

# Query (returns lazy Enumerator)
client.query("Hello").each { |msg| puts msg.content }

# Session ID (captured from first result)
client.session_id

# Abort current operation
client.abort

# Close and reset session
client.close

# Get capabilities
client.capabilities
# => { tools: [...], permission_mode: :default, max_turns: nil, model: "..." }

# Fluent configuration
client
  .with_tools(:Read, :Edit)
  .with_model("claude-sonnet-4-20250514")
  .with_permission_mode(:accept_edits)
  .with_cwd("/project")
  .with_system_prompt("Be concise")
  .with_max_turns(10)
  .with_hooks(hooks)
```

## Session

Explicit session management with memory bounds.

```ruby
# Create new session
session = RubyLLM::AgentSDK::Session.new

# With custom max messages (default: 1000)
session = RubyLLM::AgentSDK::Session.new(max_messages: 500)

# Resume existing session
session = RubyLLM::AgentSDK::Session.resume("session-id")

# Add message
session.add_message(message)

# Fork session
new_session = session.fork
new_session.forked?  # => true
new_session.parent_id  # => original session ID

# Session info
session.id
session.created_at
session.messages
session.last_message
session.to_h
```

## Tool

Custom tool definition.

```ruby
tool = RubyLLM::AgentSDK::Tool.new(
  name: "get_weather",
  description: "Get weather for a location",
  input_schema: {
    type: "object",
    properties: {
      location: { type: "string", description: "City name" }
    },
    required: ["location"]
  }
) { |args| "Weather in #{args[:location]}: Sunny" }

# Call the tool
tool.call(location: "San Francisco")

# Convert to MCP schema
tool.to_mcp_schema

# Adapt existing RubyLLM::Tool
adapted = RubyLLM::AgentSDK::Tool.from_ruby_llm_tool(MyWeatherTool)
```

## MCP Server

MCP server configuration.

```ruby
# Stdio server (external process)
server = RubyLLM::AgentSDK::MCP::Server.stdio(
  command: "npx",
  args: ["@playwright/mcp@latest"],
  env: { "DEBUG" => "true" }
)

# Ruby native server (in-process tools)
server = RubyLLM::AgentSDK::MCP::Server.ruby(tools: [weather_tool])

# Use in options
RubyLLM::AgentSDK.query(
  "Open example.com",
  mcp_servers: { playwright: server.to_cli_config }
)
```

## Errors

```ruby
# CLI not found
RubyLLM::AgentSDK::CLINotFoundError

# Process error (non-zero exit)
RubyLLM::AgentSDK::ProcessError
  error.message    # Error description
  error.exit_code  # CLI exit code
  error.stderr     # Stderr output
  error.error_code # Error code symbol

# Configuration error
RubyLLM::AgentSDK::ConfigurationError

# Hook error
RubyLLM::AgentSDK::HookError
```

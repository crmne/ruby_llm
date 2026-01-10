---
layout: default
title: Hooks
parent: Agent SDK
nav_order: 4
permalink: /agent-sdk/hooks
---

# Hooks

Run custom code at key points in the agent lifecycle.

## Overview

Hooks let you:
- **Validate** tool inputs before execution
- **Log** operations for audit trails
- **Block** dangerous operations
- **Transform** inputs and outputs
- **Inject** context into conversations

## Hook Events

The SDK supports all 12 hook events from the Claude Code CLI:

| Event | When it fires | Use cases |
|-------|---------------|-----------|
| `pre_tool_use` | Before a tool executes | Validation, logging, blocking |
| `post_tool_use` | After a tool completes | Logging, transforming output |
| `post_tool_use_failure` | When a tool fails | Error handling, recovery |
| `notification` | When agent sends notification | Alerting, UI updates |
| `user_prompt_submit` | When user submits prompt | Input validation |
| `session_start` | When session begins | Initialization |
| `session_end` | When session ends | Cleanup, reporting |
| `stop` | When agent stops | Final cleanup |
| `subagent_start` | When subagent spawns | Subagent tracking |
| `subagent_stop` | When subagent finishes | Subagent cleanup |
| `pre_compact` | Before conversation compaction | Custom compaction |
| `permission_request` | When permission needed | Custom approval flows |

## Basic Usage

```ruby
hooks = {
  pre_tool_use: [
    {
      handler: ->(context) {
        puts "Tool: #{context.tool_name}"
        puts "Input: #{context.tool_input}"
        RubyLLM::AgentSDK::Hooks::Result.approve
      }
    }
  ]
}

RubyLLM::AgentSDK.query(
  "Analyze this codebase",
  hooks: hooks
) { |msg| puts msg.content if msg.assistant? }
```

## Hook Results

Every hook must return a `Result`:

```ruby
Result = RubyLLM::AgentSDK::Hooks::Result

# Approve - continue normally
Result.approve

# Approve with modified input
Result.approve(modified_input)

# Block - stop this operation
Result.block("Reason for blocking")

# Modify - change the input
Result.modify(new_input)

# Skip - skip this hook, continue to next
Result.skip

# Stop - stop the entire agent
Result.stop("Reason for stopping")

# Add context for Claude
Result.with_context("Additional context string")

# Inject system message
Result.with_system_message("System message to inject")

# Suppress output
Result.suppress

# Async hook (returns later)
Result.async(timeout: 60)

# PreToolUse permission decision
Result.permission(:allow)
Result.permission(:deny, reason: "Not authorized")
Result.permission(:ask)
```

## Hook Context

Each hook receives a context object:

```ruby
handler: ->(context) {
  context.event        # :pre_tool_use, :post_tool_use, etc.
  context.tool_name    # "Read", "Edit", etc.
  context.tool_input   # Hash of tool input
  context.original_input  # Original (frozen) input
  context.metadata     # Additional metadata

  # Access metadata
  context[:session_id]
  context[:cwd]

  # Store custom data
  context[:my_key] = "value"
}
```

## Matchers

Filter which tools trigger your hooks:

```ruby
hooks = {
  pre_tool_use: [
    # Match specific tool
    {
      matcher: "Edit",
      handler: ->(ctx) { ... }
    },

    # Match multiple tools
    {
      matcher: ["Edit", "Write"],
      handler: ->(ctx) { ... }
    },

    # Match with regex
    {
      matcher: /Bash|Edit|Write/,
      handler: ->(ctx) { ... }
    },

    # Match with proc
    {
      matcher: ->(tool) { tool.start_with?("Web") },
      handler: ->(ctx) { ... }
    },

    # No matcher = match all
    {
      handler: ->(ctx) { ... }
    }
  ]
}
```

## Input Types

Each event has a specific input type:

### PreToolUseInput

```ruby
input.session_id
input.transcript_path
input.cwd
input.permission_mode
input.tool_name
input.tool_input
input.hook_event_name  # => :pre_tool_use
```

### PostToolUseInput

```ruby
input.tool_name
input.tool_input
input.tool_response  # Output from the tool
```

### SessionStartInput

```ruby
input.source  # 'startup', 'resume', 'clear', 'compact'
```

### SessionEndInput

```ruby
input.reason  # Exit reason
```

### NotificationInput

```ruby
input.message
input.title
```

## Common Patterns

### Audit Logging

```ruby
audit_log = []

hooks = {
  pre_tool_use: [
    {
      handler: ->(ctx) {
        audit_log << {
          timestamp: Time.now,
          tool: ctx.tool_name,
          input: ctx.tool_input.dup
        }
        Result.approve
      }
    }
  ],
  session_end: [
    {
      handler: ->(ctx) {
        File.write("audit.json", JSON.pretty_generate(audit_log))
        Result.approve
      }
    }
  ]
}
```

### Blocking Dangerous Operations

```ruby
DANGEROUS_PATTERNS = [
  /rm\s+-rf/,
  /DROP\s+TABLE/i,
  /sudo/
]

hooks = {
  pre_tool_use: [
    {
      matcher: "Bash",
      handler: ->(ctx) {
        command = ctx.tool_input[:command]
        if DANGEROUS_PATTERNS.any? { |p| command.match?(p) }
          Result.block("Dangerous command blocked: #{command}")
        else
          Result.approve
        end
      }
    }
  ]
}
```

### Path Sandboxing

```ruby
ALLOWED_DIRS = ["/projects/myapp", "/tmp"]

hooks = {
  pre_tool_use: [
    {
      matcher: ["Read", "Write", "Edit"],
      handler: ->(ctx) {
        path = ctx.tool_input[:file_path]
        expanded = File.expand_path(path)

        unless ALLOWED_DIRS.any? { |dir| expanded.start_with?(dir) }
          Result.block("Access denied: #{path} outside allowed directories")
        else
          Result.approve
        end
      }
    }
  ]
}
```

### Cost Tracking

```ruby
total_cost = 0.0
MAX_BUDGET = 5.0

hooks = {
  post_tool_use: [
    {
      handler: ->(ctx) {
        # Track based on tool usage (simplified)
        cost = case ctx.tool_name
               when "WebSearch" then 0.01
               when "WebFetch" then 0.005
               else 0.0
               end

        total_cost += cost

        if total_cost > MAX_BUDGET
          Result.stop("Budget exceeded: $#{total_cost.round(2)}")
        else
          Result.approve
        end
      }
    }
  ]
}
```

### Progress Notifications

```ruby
hooks = {
  post_tool_use: [
    {
      handler: ->(ctx) {
        case ctx.tool_name
        when "Read"
          puts "Read: #{ctx.tool_input[:file_path]}"
        when "Edit"
          puts "Edited: #{ctx.tool_input[:file_path]}"
        when "Bash"
          puts "Executed: #{ctx.tool_input[:command]}"
        end
        Result.approve
      }
    }
  ]
}
```

## Error Handling

By default, hooks fail **closed** - errors block operations:

```ruby
# Hook that might raise
hooks = {
  pre_tool_use: [
    {
      handler: ->(ctx) {
        # If this raises, the operation is BLOCKED
        result = some_external_api_call(ctx.tool_input)
        Result.approve
      }
    }
  ]
}
```

### Configuring Fail Mode

```ruby
# Create runner with fail-open behavior (less secure)
runner = RubyLLM::AgentSDK::Hooks::Runner.new(hooks, fail_mode: :open)

# Per-hook fail mode
hooks = {
  pre_tool_use: [
    {
      handler: ->(ctx) { ... },
      fail_mode: :open  # This hook fails open
    }
  ]
}
```

### Logging Hook Failures

```ruby
# Configure a logger
RubyLLM::AgentSDK::Hooks.logger = Rails.logger

# Now hook failures are logged with context
```

## Timeout

Hooks have a default 60-second timeout:

```ruby
hooks = {
  pre_tool_use: [
    {
      handler: ->(ctx) {
        sleep(120)  # This will timeout
        Result.approve
      },
      timeout: 30  # Override: 30 second timeout
    }
  ]
}
```

## Using with Client

```ruby
client = RubyLLM::AgentSDK.client
  .with_hooks({
    pre_tool_use: [
      { handler: ->(ctx) { ... } }
    ]
  })

# Hooks apply to all queries
client.query("First query").each { |msg| ... }
client.query("Second query").each { |msg| ... }
```

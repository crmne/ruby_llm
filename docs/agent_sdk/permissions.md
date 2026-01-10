---
layout: default
title: Permissions
parent: Agent SDK
nav_order: 7
permalink: /agent-sdk/permissions
---

# Permissions

Control exactly which tools your agent can use.

## Permission Modes

| Mode | Symbol | Description |
|------|--------|-------------|
| Default | `:default` | Standard permission behavior |
| Accept Edits | `:accept_edits` | Auto-accept file edits |
| Bypass | `:bypass_permissions` | Bypass all permission checks |
| Plan | `:plan` | Planning mode - no execution |

```ruby
# Read-only analysis mode
RubyLLM::AgentSDK.query(
  "Review this code",
  permission_mode: :bypass_permissions,
  allowed_tools: %w[Read Glob Grep]
)

# Auto-accept file changes
RubyLLM::AgentSDK.query(
  "Fix all bugs",
  permission_mode: :accept_edits,
  allowed_tools: %w[Read Edit Write Bash]
)

# Planning only (no execution)
RubyLLM::AgentSDK.query(
  "Plan a refactoring strategy",
  permission_mode: :plan
)
```

## Tool Allowlists

Restrict which tools the agent can use:

```ruby
# Only allow reading
RubyLLM::AgentSDK.query(
  "Analyze the codebase",
  allowed_tools: %w[Read Glob Grep]
)

# Allow everything except dangerous tools
RubyLLM::AgentSDK.query(
  "Help with the project",
  disallowed_tools: %w[Bash Write]
)

# Fluent API
client = RubyLLM::AgentSDK.client
  .with_tools(:Read, :Edit, :Glob, :Grep)
  .without_tools(:Bash, :WebSearch)
```

## Built-in Tools

All available tools:

| Tool | Risk | Description |
|------|------|-------------|
| Read | Low | Read files |
| Glob | Low | Find files by pattern |
| Grep | Low | Search file contents |
| LS | Low | List directory contents |
| WebSearch | Low | Search the web |
| WebFetch | Low | Fetch web pages |
| AskUserQuestion | Low | Ask clarifying questions |
| TodoWrite | Low | Track tasks |
| Edit | Medium | Modify files |
| Write | Medium | Create files |
| NotebookEdit | Medium | Edit Jupyter notebooks |
| Bash | High | Execute commands |
| Agent | High | Spawn subagents |
| KillShell | High | Kill processes |
| ExitPlanMode | Low | Exit planning |
| EnterPlanMode | Low | Enter planning |
| TaskOutput | Low | Get task output |

## Custom Permission Handler

Use hooks for fine-grained control:

```ruby
hooks = {
  pre_tool_use: [
    {
      handler: ->(ctx) {
        # Custom logic
        if ctx.tool_name == "Bash"
          command = ctx.tool_input[:command]

          # Block dangerous commands
          if command.include?("rm") || command.include?("sudo")
            return RubyLLM::AgentSDK::Hooks::Result.block("Command not allowed")
          end

          # Require confirmation for others
          if command.include?("git push")
            # Could integrate with external approval system
            return RubyLLM::AgentSDK::Hooks::Result.permission(:ask)
          end
        end

        RubyLLM::AgentSDK::Hooks::Result.approve
      }
    }
  ]
}

RubyLLM::AgentSDK.query("Deploy the app", hooks: hooks)
```

## Path-based Permissions

Restrict file access to specific directories:

```ruby
ALLOWED_PATHS = [
  "/home/user/projects/myapp",
  "/tmp"
]

BLOCKED_PATHS = [
  "~/.ssh",
  "~/.aws",
  "~/.config",
  ".env"
]

hooks = {
  pre_tool_use: [
    {
      matcher: ["Read", "Write", "Edit"],
      handler: ->(ctx) {
        path = ctx.tool_input[:file_path]
        expanded = File.expand_path(path)

        # Check blocked paths
        if BLOCKED_PATHS.any? { |p| expanded.include?(File.expand_path(p)) }
          return Hooks::Result.block("Access to #{path} is blocked")
        end

        # Check allowed paths
        unless ALLOWED_PATHS.any? { |p| expanded.start_with?(p) }
          return Hooks::Result.block("#{path} is outside allowed directories")
        end

        Hooks::Result.approve
      }
    }
  ]
}
```

## Bypass Permissions (Dangerous)

For fully automated pipelines:

```ruby
RubyLLM::AgentSDK.query(
  "Run the deployment script",
  permission_mode: :bypass_permissions,
  allow_dangerously_skip_permissions: true  # Required flag
)
```

{: .warning }
Only use `bypass_permissions` in trusted environments. The agent will execute all operations without confirmation.

## Additional Directories

Grant access to directories outside `cwd`:

```ruby
RubyLLM::AgentSDK.query(
  "Compare the two projects",
  cwd: "/projects/app-v1",
  additional_directories: ["/projects/app-v2", "/shared/configs"]
)
```

## Permission Denials

Track what was blocked:

```ruby
RubyLLM::AgentSDK.query("Do everything") do |msg|
  if msg.result?
    msg.permission_denials.each do |denial|
      puts "Blocked: #{denial[:tool_name]}"
      puts "  Input: #{denial[:tool_input]}"
      puts "  ID: #{denial[:tool_use_id]}"
    end
  end
end
```

## CI/CD Example

Safe configuration for automated pipelines:

```ruby
# ci_agent.rb
RubyLLM::AgentSDK.query(
  "Run tests and report failures",
  permission_mode: :bypass_permissions,
  allow_dangerously_skip_permissions: true,
  allowed_tools: %w[Read Glob Grep Bash],
  disallowed_tools: %w[Write Edit WebSearch],  # No modifications
  cwd: ENV['CI_PROJECT_DIR'],
  max_budget_usd: 1.0,
  max_turns: 20,
  hooks: {
    pre_tool_use: [
      {
        matcher: "Bash",
        handler: ->(ctx) {
          command = ctx.tool_input[:command]

          # Only allow specific commands
          allowed = ["bundle exec rspec", "npm test", "pytest"]
          if allowed.any? { |a| command.start_with?(a) }
            Hooks::Result.approve
          else
            Hooks::Result.block("Only test commands allowed")
          end
        }
      }
    ]
  }
) do |msg|
  puts msg.content if msg.result?
end
```

## Sandbox Configuration

OS-level sandboxing for Bash commands:

```ruby
RubyLLM::AgentSDK.query(
  "Build the project",
  sandbox: {
    enabled: true,
    auto_allow_bash_if_sandboxed: true,
    excluded_commands: ["docker"],  # Always bypass sandbox
    network: {
      allow_local_binding: true,     # For dev servers
      allow_unix_sockets: ["/var/run/docker.sock"]
    }
  }
)
```

{: .note }
Sandboxing uses OS-level features (macOS seatbelt, Linux bubblewrap) and requires Claude Code CLI support.

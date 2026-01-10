---
layout: default
title: Quickstart
parent: Agent SDK
nav_order: 1
permalink: /agent-sdk/quickstart
---

# Quickstart

Build an agent that finds and fixes bugs in minutes.

## Prerequisites

1. Ruby 3.1+ installed
2. Claude Code CLI installed
3. Anthropic API key

```bash
# Install Claude Code CLI
npm install -g @anthropic-ai/claude-code

# Set API key
export ANTHROPIC_API_KEY=your-api-key
```

## Step 1: Install RubyLLM

```ruby
# Gemfile
gem 'ruby_llm'
```

```bash
bundle install
```

## Step 2: Create Your First Agent

Create `bug_fixer.rb`:

```ruby
require 'ruby_llm'

# Find and fix bugs in a Ruby file
RubyLLM::AgentSDK.query(
  "Find and fix any bugs in lib/calculator.rb",
  allowed_tools: %w[Read Edit Glob Grep],
  permission_mode: :accept_edits,
  cwd: Dir.pwd
) do |message|
  case message.type
  when :system
    puts "Session started: #{message.session_id}" if message.init?
  when :assistant
    puts message.content if message.content
  when :result
    if message.success?
      puts "\nDone!"
      puts "Turns: #{message.num_turns}"
      puts "Cost: $#{message.total_cost_usd.round(4)}"
    else
      puts "Error: #{message.errors.join(', ')}"
    end
  end
end
```

## Step 3: Create a Test File

Create `lib/calculator.rb` with an intentional bug:

```ruby
class Calculator
  def add(a, b)
    a - b  # Bug: should be +
  end

  def divide(a, b)
    a / b  # Bug: no zero check
  end
end
```

## Step 4: Run Your Agent

```bash
ruby bug_fixer.rb
```

The agent will:
1. Read the file
2. Identify the bugs
3. Edit the file to fix them
4. Report what it changed

## Step 5: Multi-turn Client

For ongoing conversations, use the Client:

```ruby
require 'ruby_llm'

client = RubyLLM::AgentSDK.client(
  model: "claude-sonnet-4-20250514",
  allowed_tools: %w[Read Edit Glob Grep Bash],
  permission_mode: :accept_edits
)

# First query - analyze the codebase
client.query("Analyze the test coverage in this project").each do |msg|
  puts msg.content if msg.assistant?
end

# Second query - Claude remembers context
client.query("Which files need more tests?").each do |msg|
  puts msg.content if msg.assistant?
end

# Third query - implement based on analysis
client.query("Add tests for the most critical untested file").each do |msg|
  puts msg.content if msg.assistant?
end
```

## Step 6: Add Hooks for Monitoring

Track what your agent does:

```ruby
require 'ruby_llm'

audit_log = []

hooks = {
  pre_tool_use: [
    {
      handler: ->(ctx) {
        audit_log << {
          time: Time.now,
          tool: ctx.tool_name,
          input: ctx.tool_input
        }
        RubyLLM::AgentSDK::Hooks::Result.approve
      }
    }
  ],
  session_end: [
    {
      handler: ->(ctx) {
        puts "\n=== Audit Log ==="
        audit_log.each do |entry|
          puts "#{entry[:time]}: #{entry[:tool]}"
        end
        RubyLLM::AgentSDK::Hooks::Result.approve
      }
    }
  ]
}

RubyLLM::AgentSDK.query(
  "Refactor the User model to use concerns",
  hooks: hooks,
  permission_mode: :accept_edits
) do |msg|
  puts msg.content if msg.assistant?
end
```

## Common Patterns

### Collect Final Result

```ruby
result = RubyLLM::AgentSDK.query("What is 2+2?").find(&:result?)
puts result.content
```

### Stream with Progress

```ruby
RubyLLM::AgentSDK.query("Analyze this codebase").each do |msg|
  case msg.type
  when :assistant
    print msg.content
    $stdout.flush
  when :result
    puts "\n\nAnalysis complete!"
  end
end
```

### Error Handling

```ruby
begin
  RubyLLM::AgentSDK.query("Fix all bugs").each do |msg|
    # Process messages
  end
rescue RubyLLM::AgentSDK::CLINotFoundError
  puts "Please install Claude Code: npm install -g @anthropic-ai/claude-code"
rescue RubyLLM::AgentSDK::ProcessError => e
  puts "CLI error: #{e.message}"
  puts "Exit code: #{e.exit_code}"
end
```

## Next Steps

- [API Reference]({% link agent_sdk/api-reference.md %}) - Full documentation of all options
- [Rails Integration]({% link agent_sdk/rails.md %}) - Use in Rails apps with background jobs
- [Hooks]({% link agent_sdk/hooks.md %}) - Deep dive into the hook system
- [Examples]({% link agent_sdk/examples.md %}) - Real-world agent implementations

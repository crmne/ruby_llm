---
layout: default
title: Examples
parent: Agent SDK
nav_order: 9
permalink: /agent-sdk/examples
---

# Examples

Real-world agent implementations.

## Code Review Agent

```ruby
# code_reviewer.rb
require 'ruby_llm'

class CodeReviewAgent
  def initialize(repo_path)
    @repo_path = repo_path
    @client = RubyLLM::AgentSDK.client(
      cwd: repo_path,
      model: "claude-sonnet-4-20250514",
      allowed_tools: %w[Read Glob Grep Bash],
      permission_mode: :bypass_permissions
    )
  end

  def review_pr(branch)
    findings = []

    @client.query("Review the changes in #{branch} compared to main").each do |msg|
      if msg.assistant? && msg.content
        findings << msg.content
      end
    end

    @client.query("Focus on security issues").each do |msg|
      findings << msg.content if msg.assistant? && msg.content
    end

    @client.query("Summarize your findings as a JSON report").find(&:result?)
  end
end

# Usage
reviewer = CodeReviewAgent.new("/path/to/repo")
result = reviewer.review_pr("feature/new-auth")
puts result.structured_output if result.structured_output
```

## Research Assistant

```ruby
# research_agent.rb
require 'ruby_llm'

def research_topic(topic, output_file:)
  findings = []

  RubyLLM::AgentSDK.query(
    "Research: #{topic}. Find authoritative sources and summarize key points.",
    allowed_tools: %w[WebSearch WebFetch],
    max_turns: 20,
    max_budget_usd: 2.0,
    hooks: {
      post_tool_use: [
        {
          matcher: "WebSearch",
          handler: ->(ctx) {
            puts "Searched: #{ctx.tool_input[:query]}"
            RubyLLM::AgentSDK::Hooks::Result.approve
          }
        }
      ]
    }
  ) do |msg|
    findings << msg.content if msg.assistant? && msg.content
  end

  File.write(output_file, findings.join("\n\n"))
  puts "Research saved to #{output_file}"
end

# Usage
research_topic("Ruby 3.4 new features", output_file: "ruby34_research.md")
```

## Filesystem Agent

```ruby
# fs_agent.rb
require 'ruby_llm'

def organize_files(directory, rules:)
  RubyLLM::AgentSDK.query(
    "Organize files in #{directory} according to these rules: #{rules}",
    cwd: directory,
    allowed_tools: %w[Read Write Glob Bash],
    permission_mode: :accept_edits,
    hooks: {
      pre_tool_use: [
        {
          matcher: "Bash",
          handler: ->(ctx) {
            command = ctx.tool_input[:command]
            # Only allow mv, mkdir, cp
            if command.match?(/^(mv|mkdir|cp)\s/)
              RubyLLM::AgentSDK::Hooks::Result.approve
            else
              RubyLLM::AgentSDK::Hooks::Result.block("Only mv/mkdir/cp allowed")
            end
          }
        }
      ]
    }
  ) do |msg|
    puts msg.content if msg.assistant?
  end
end

# Usage
organize_files(
  "~/Downloads",
  rules: "Move images to ~/Pictures, documents to ~/Documents, delete temp files"
)
```

## Data Extraction Agent

```ruby
# extractor.rb
require 'ruby_llm'

def extract_data(url, schema:)
  result = RubyLLM::AgentSDK.query(
    "Extract structured data from #{url}",
    allowed_tools: %w[WebFetch],
    output_format: { type: 'json_schema', schema: schema }
  ).find(&:result?)

  result.structured_output
end

# Usage
products = extract_data(
  "https://example.com/products",
  schema: {
    type: "object",
    properties: {
      products: {
        type: "array",
        items: {
          type: "object",
          properties: {
            name: { type: "string" },
            price: { type: "number" },
            in_stock: { type: "boolean" }
          }
        }
      }
    }
  }
)

puts products # => { products: [...] }
```

## Bug Fixer with Hooks

```ruby
# bug_fixer.rb
require 'ruby_llm'

changes = []

hooks = {
  pre_tool_use: [
    {
      matcher: "Edit",
      handler: ->(ctx) {
        changes << {
          file: ctx.tool_input[:file_path],
          old: ctx.tool_input[:old_string],
          new: ctx.tool_input[:new_string]
        }
        RubyLLM::AgentSDK::Hooks::Result.approve
      }
    }
  ],
  session_end: [
    {
      handler: ->(ctx) {
        puts "\n=== Changes Made ==="
        changes.each do |c|
          puts "File: #{c[:file]}"
          puts "- #{c[:old]}"
          puts "+ #{c[:new]}"
          puts
        end
        RubyLLM::AgentSDK::Hooks::Result.approve
      }
    }
  ]
}

RubyLLM::AgentSDK.query(
  "Find and fix bugs in the authentication module",
  cwd: "/path/to/project",
  allowed_tools: %w[Read Edit Glob Grep],
  permission_mode: :accept_edits,
  hooks: hooks
) do |msg|
  puts msg.content if msg.assistant?
end
```

## Interactive Helper

```ruby
# helper.rb
require 'ruby_llm'

class InteractiveHelper
  def initialize
    @client = RubyLLM::AgentSDK.client(
      allowed_tools: %w[Read Glob Grep AskUserQuestion],
      permission_mode: :default
    )
  end

  def run
    puts "Interactive Helper - type 'quit' to exit"
    puts

    loop do
      print "> "
      input = gets&.chomp
      break if input.nil? || input == 'quit'

      @client.query(input).each do |msg|
        if msg.assistant? && msg.content
          puts msg.content
        end
      end
      puts
    end
  end
end

# Usage
InteractiveHelper.new.run
```

## MCP Browser Agent

```ruby
# browser_agent.rb
require 'ruby_llm'

def browse_and_extract(url, task)
  RubyLLM::AgentSDK.query(
    "Go to #{url} and #{task}",
    mcp_servers: {
      playwright: {
        type: 'stdio',
        command: 'npx',
        args: ['@playwright/mcp@latest']
      }
    },
    max_turns: 30
  ) do |msg|
    puts msg.content if msg.assistant?
  end
end

# Usage
browse_and_extract(
  "https://news.ycombinator.com",
  "find the top 5 stories and summarize them"
)
```

## Subagent Example

```ruby
# subagent_example.rb
require 'ruby_llm'

RubyLLM::AgentSDK.query(
  "Use the security-reviewer agent to audit the authentication code",
  allowed_tools: %w[Read Glob Grep Task],
  agents: {
    "security-reviewer" => {
      description: "Expert security code reviewer",
      prompt: "You are a security expert. Analyze code for vulnerabilities including SQL injection, XSS, CSRF, and authentication bypasses. Be thorough and cite specific line numbers.",
      tools: ["Read", "Glob", "Grep"],
      model: "sonnet"  # Can use different model for subagent
    },
    "test-writer" => {
      description: "Test case generator",
      prompt: "Generate comprehensive test cases for the given code. Focus on edge cases and error conditions.",
      tools: ["Read", "Write", "Glob"]
    }
  }
) do |msg|
  # Track which subagent is responding
  if msg.parent_tool_use_id
    puts "[Subagent] #{msg.content}" if msg.assistant?
  else
    puts msg.content if msg.assistant?
  end
end
```

## Cost-Limited Agent

```ruby
# budget_agent.rb
require 'ruby_llm'

def run_with_budget(task, max_budget: 1.0)
  total_cost = 0.0

  RubyLLM::AgentSDK.query(
    task,
    max_budget_usd: max_budget
  ) do |msg|
    if msg.result?
      total_cost = msg.total_cost_usd
      if msg.error_max_budget?
        puts "Budget limit reached at $#{total_cost.round(4)}"
      else
        puts "Completed! Cost: $#{total_cost.round(4)}"
      end
    end
  end

  total_cost
end

# Usage
cost = run_with_budget("Analyze this large codebase", max_budget: 0.50)
puts "Total spent: $#{cost.round(4)}"
```

## Rails Integration

```ruby
# app/services/claude_agent.rb
class ClaudeAgent
  include Singleton

  def analyze_code(file_path)
    messages = []

    RubyLLM::AgentSDK.query(
      "Analyze #{file_path} for code quality issues",
      cwd: Rails.root.to_s,
      allowed_tools: %w[Read Glob Grep],
      permission_mode: :bypass_permissions
    ) do |msg|
      messages << msg.content if msg.assistant? && msg.content
    end

    messages.join("\n")
  end

  def suggest_improvements(model_name)
    RubyLLM::AgentSDK.query(
      "Review the #{model_name} model and suggest improvements",
      cwd: Rails.root.to_s,
      allowed_tools: %w[Read Glob Grep],
      permission_mode: :bypass_permissions
    ).find(&:result?)&.content
  end
end

# Usage in controller
class CodeReviewsController < ApplicationController
  def create
    analysis = ClaudeAgent.instance.analyze_code(params[:file_path])
    render json: { analysis: analysis }
  end
end
```

## More Examples

See the `examples/agent_sdk/` directory in the repository for additional examples:

- `hello_world.rb` - Basic usage
- `streaming.rb` - Streaming patterns
- `with_hooks.rb` - Hook configurations
- `mcp_tools.rb` - MCP server examples
- `tool_permissions.rb` - Permission patterns
- `structured_output.rb` - JSON extraction
- `max_budget.rb` - Cost management
- `research_agent.rb` - Web research
- `filesystem_agent.rb` - File operations

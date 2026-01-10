---
layout: default
title: Sessions
parent: Agent SDK
nav_order: 6
permalink: /agent-sdk/sessions
---

# Sessions

Maintain context across multiple exchanges.

## Overview

Sessions allow your agent to:
- Remember files it has read
- Continue multi-step tasks
- Reference previous analysis
- Fork conversations to explore alternatives

## Capturing Session ID

The session ID is available in the init message:

```ruby
session_id = nil

RubyLLM::AgentSDK.query("Analyze the codebase") do |msg|
  if msg.init?
    session_id = msg.session_id
    puts "Started session: #{session_id}"
  end

  puts msg.content if msg.assistant?
end

puts "Session ID for later: #{session_id}"
```

## Resuming Sessions

Continue a previous conversation:

```ruby
# Later, resume with full context
RubyLLM::AgentSDK.query(
  "What did you find?",  # Claude remembers the analysis
  resume: session_id
) do |msg|
  puts msg.content if msg.assistant?
end
```

## Using the Client

The `Client` class handles session management automatically:

```ruby
client = RubyLLM::AgentSDK.client(
  model: "claude-sonnet-4-20250514",
  allowed_tools: %w[Read Glob Grep]
)

# First query - session is created
client.query("Read the User model").each do |msg|
  puts msg.content if msg.assistant?
end

puts "Session: #{client.session_id}"

# Second query - same session, full context
client.query("What validations does it have?").each do |msg|
  puts msg.content if msg.assistant?
end

# Third query - continues the conversation
client.query("Add email format validation").each do |msg|
  puts msg.content if msg.assistant?
end
```

## Forking Sessions

Explore different approaches without losing the original:

```ruby
# Start a conversation
client = RubyLLM::AgentSDK.client
client.query("Analyze the authentication system").each { |msg| ... }

original_session = client.session_id

# Fork to try a different approach
RubyLLM::AgentSDK.query(
  "Rewrite using JWT instead",
  resume: original_session,
  fork_session: true  # Creates new session from this point
) do |msg|
  if msg.init?
    puts "Forked to: #{msg.session_id}"
  end
end

# Original session is unchanged - can resume it too
RubyLLM::AgentSDK.query(
  "Continue with the original approach",
  resume: original_session
) { |msg| ... }
```

## Continue Latest

Continue the most recent session without specifying ID:

```ruby
# Continue whatever you were doing last
RubyLLM::AgentSDK.query(
  "Continue where we left off",
  continue: true
) do |msg|
  puts msg.content if msg.assistant?
end
```

## Resume at Specific Point

Resume from a specific message in the conversation:

```ruby
# Resume but skip to a specific point
RubyLLM::AgentSDK.query(
  "Try a different approach from here",
  resume: session_id,
  resume_session_at: message_uuid  # UUID of the message to resume from
)
```

## Session Class

For explicit session management:

```ruby
# Create new session
session = RubyLLM::AgentSDK::Session.new
puts session.id        # => "random-session-id"
puts session.created_at
puts session.messages  # => []

# With memory limits
session = RubyLLM::AgentSDK::Session.new(max_messages: 500)

# Add messages
session.add_message(message)
session.last_message

# When limit exceeded, oldest messages are dropped (FIFO)

# Resume existing
session = RubyLLM::AgentSDK::Session.resume("known-session-id")

# Fork session
new_session = session.fork
new_session.forked?     # => true
new_session.parent_id   # => original session ID
```

## Session Info from Messages

```ruby
RubyLLM::AgentSDK.query("Hello") do |msg|
  # Init message has session details
  if msg.init?
    puts "Session ID: #{msg.session_id}"
    puts "Working Dir: #{msg.cwd}"
    puts "Model: #{msg.model}"
    puts "Permission Mode: #{msg.permission_mode}"
    puts "Available Tools: #{msg.tools.join(', ')}"
    puts "MCP Servers: #{msg.mcp_servers.map { |s| s[:name] }}"
  end

  # Result message also has session ID
  if msg.result?
    puts "Session: #{msg.session_id}"
    puts "Turns: #{msg.num_turns}"
    puts "Cost: $#{msg.total_cost_usd}"
  end
end
```

## Compact Boundaries

When conversations get long, Claude compacts them:

```ruby
RubyLLM::AgentSDK.query("Very long conversation...") do |msg|
  if msg.compact_boundary?
    metadata = msg.compact_metadata
    puts "Compacted!"
    puts "Trigger: #{metadata[:trigger]}"  # 'manual' or 'auto'
    puts "Pre-tokens: #{metadata[:pre_tokens]}"
  end
end
```

## Multi-User Sessions

Track sessions per user:

```ruby
class AgentSession
  def initialize(user_id)
    @user_id = user_id
    @session_id = load_session_id
  end

  def query(prompt)
    RubyLLM::AgentSDK.query(
      prompt,
      resume: @session_id
    ) do |msg|
      @session_id = msg.session_id if msg.init?
      yield msg if block_given?
    end

    save_session_id
  end

  private

  def load_session_id
    Redis.current.get("agent:session:#{@user_id}")
  end

  def save_session_id
    Redis.current.set("agent:session:#{@user_id}", @session_id) if @session_id
  end
end

# Usage
session = AgentSession.new(current_user.id)
session.query("Help me with my code") { |msg| ... }
```

## Session Cleanup

```ruby
client = RubyLLM::AgentSDK.client

# Work with the agent
client.query("Do some work").each { |msg| ... }

# Abort current operation
client.abort

# Clear session and start fresh
client.close
client.session_id  # => nil

# Next query starts new session
client.query("Fresh start").each { |msg| ... }
```

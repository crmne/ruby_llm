---
layout: default
title: MCP
parent: Agent SDK
nav_order: 5
permalink: /agent-sdk/mcp
---

# MCP (Model Context Protocol)

Connect external systems to your agent via the Model Context Protocol.

## Overview

MCP allows your agent to interact with:
- Databases (PostgreSQL, SQLite)
- Browsers (Playwright)
- APIs (GitHub, Slack)
- File systems
- Custom tools

## Server Types

### Stdio Servers

External processes that communicate via stdin/stdout:

```ruby
# Playwright for browser automation
RubyLLM::AgentSDK.query(
  "Open example.com and screenshot it",
  mcp_servers: {
    playwright: {
      type: 'stdio',
      command: 'npx',
      args: ['@playwright/mcp@latest']
    }
  }
)

# GitHub for repository operations
RubyLLM::AgentSDK.query(
  "List open issues in my repo",
  mcp_servers: {
    github: {
      type: 'stdio',
      command: 'npx',
      args: ['-y', '@modelcontextprotocol/server-github'],
      env: { 'GITHUB_TOKEN' => ENV['GITHUB_TOKEN'] }
    }
  }
)

# SQLite for database queries
RubyLLM::AgentSDK.query(
  "List all users from the database",
  mcp_servers: {
    sqlite: {
      type: 'stdio',
      command: 'npx',
      args: ['-y', '@modelcontextprotocol/server-sqlite', 'db/development.sqlite3']
    }
  }
)
```

### Ruby Native Servers

In-process tools written in Ruby:

```ruby
# Define custom tools
weather_tool = RubyLLM::AgentSDK.tool(
  name: "get_weather",
  description: "Get current weather for a location",
  input_schema: {
    location: { type: "string", description: "City name" }
  }
) do |args|
  # Your Ruby code here
  api_response = WeatherAPI.current(args[:location])
  "Weather in #{args[:location]}: #{api_response.description}, #{api_response.temp}F"
end

database_tool = RubyLLM::AgentSDK.tool(
  name: "query_users",
  description: "Query users from the database",
  input_schema: {
    filter: { type: "string", description: "SQL WHERE clause" }
  }
) do |args|
  User.where(args[:filter]).to_json
end

# Create MCP server with your tools
server = RubyLLM::AgentSDK.create_sdk_mcp_server(
  tools: [weather_tool, database_tool]
)

# Use in query
RubyLLM::AgentSDK.query(
  "What's the weather in San Francisco? Also show me active users.",
  mcp_servers: { ruby_tools: server.to_cli_config }
)
```

## Using MCP::Server Class

```ruby
# Stdio server
server = RubyLLM::AgentSDK::MCP::Server.stdio(
  command: 'npx',
  args: ['@playwright/mcp@latest'],
  env: { 'DEBUG' => 'true' }
)

# Ruby native server
server = RubyLLM::AgentSDK::MCP::Server.ruby(
  tools: [weather_tool, database_tool]
)

# Convert to CLI config
config = server.to_cli_config
# => { type: 'stdio', command: 'npx', args: [...], env: {...} }
```

## Multiple Servers

Connect multiple MCP servers simultaneously:

```ruby
RubyLLM::AgentSDK.query(
  "Check the weather, then create a GitHub issue about it",
  mcp_servers: {
    weather: {
      type: 'stdio',
      command: 'weather-mcp-server',
      args: []
    },
    github: {
      type: 'stdio',
      command: 'npx',
      args: ['-y', '@modelcontextprotocol/server-github'],
      env: { 'GITHUB_TOKEN' => ENV['GITHUB_TOKEN'] }
    }
  }
)
```

## With Client

```ruby
client = RubyLLM::AgentSDK.client

# Add MCP server
client.options.with_mcp_server(:playwright, {
  type: 'stdio',
  command: 'npx',
  args: ['@playwright/mcp@latest']
})

# Now all queries can use playwright tools
client.query("Take a screenshot of hacker news").each { |msg| ... }
```

## Popular MCP Servers

| Server | Package | Use Case |
|--------|---------|----------|
| Playwright | `@playwright/mcp` | Browser automation |
| GitHub | `@modelcontextprotocol/server-github` | Repository operations |
| SQLite | `@modelcontextprotocol/server-sqlite` | Database queries |
| Filesystem | `@modelcontextprotocol/server-filesystem` | File operations |
| Slack | `@modelcontextprotocol/server-slack` | Slack integration |
| Memory | `@modelcontextprotocol/server-memory` | Persistent memory |

Find more at [github.com/modelcontextprotocol/servers](https://github.com/modelcontextprotocol/servers)

## Custom Tool Schema

Tool schemas follow JSON Schema:

```ruby
complex_tool = RubyLLM::AgentSDK.tool(
  name: "search_products",
  description: "Search product catalog",
  input_schema: {
    type: "object",
    properties: {
      query: {
        type: "string",
        description: "Search query"
      },
      category: {
        type: "string",
        enum: ["electronics", "clothing", "home"],
        description: "Product category"
      },
      max_price: {
        type: "number",
        description: "Maximum price filter"
      },
      in_stock: {
        type: "boolean",
        description: "Only show in-stock items"
      }
    },
    required: ["query"]
  }
) do |args|
  Product.search(
    args[:query],
    category: args[:category],
    max_price: args[:max_price],
    in_stock: args[:in_stock]
  ).to_json
end
```

## Adapting RubyLLM Tools

Convert existing `RubyLLM::Tool` classes:

```ruby
class MyWeatherTool < RubyLLM::Tool
  description "Get weather for a location"

  param :location, type: :string, description: "City name", required: true

  def call(location:)
    WeatherAPI.current(location).to_s
  end
end

# Adapt for Agent SDK
adapted_tool = RubyLLM::AgentSDK::Tool.from_ruby_llm_tool(MyWeatherTool)

# Use in MCP server
server = RubyLLM::AgentSDK.create_sdk_mcp_server(tools: [adapted_tool])
```

## Error Handling

```ruby
RubyLLM::AgentSDK.query(
  "Use the broken server",
  mcp_servers: { broken: { type: 'stdio', command: 'nonexistent' } }
) do |msg|
  if msg.init?
    # Check server status
    msg.mcp_servers.each do |server|
      puts "#{server[:name]}: #{server[:status]}"
      # status: 'connected', 'failed', 'pending', 'needs-auth'
    end
  end
end
```

## Strict Mode

Enable strict validation of MCP configurations:

```ruby
RubyLLM::AgentSDK.query(
  "Use MCP tools",
  mcp_servers: { ... },
  strict_mcp_config: true  # Fail on invalid configs
)
```

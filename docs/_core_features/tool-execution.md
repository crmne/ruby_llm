---
layout: default
title: Controlling Tool Execution
parent: "Tools"
nav_order: 2
description: Steer which tools the model uses, how many calls it makes, whether they run concurrently, and observe each call with callbacks.
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

* How to control whether the model can call tools and which one.
* How to limit how many tool calls appear in one assistant response.
* How to run multiple tool calls concurrently for I/O-bound work.
* What happens when a model does not support function calling.
* How to observe tool calls and results with callbacks.
* How to cap tool usage to prevent runaway loops.

By default RubyLLM lets the model decide when to call tools and runs them sequentially. When you need tighter control, these options let you steer tool choice, parallelism, and observability per chat.

## Tool Call Controls

Control tool behavior with two options:
- `choice` controls which tools the model is allowed/required to use.
- `calls` controls how many tool calls can appear in one assistant response.

### Tool Choice (`choice`)

Use `choice` to control whether the model can call tools and which one it can call.

```ruby
# Model decides if a tool is needed
chat.with_tools(Weather, Calculator, choice: :auto)

# Model must call a tool
chat.with_tools(Weather, Calculator, choice: :required)

# Disable tool calls
chat.with_tools(Weather, Calculator, choice: :none)

# Force one specific tool (symbol or class)
chat.with_tools(Weather, Calculator, choice: :weather)
chat.with_tools(Weather, Calculator, choice: Weather)
```

Valid values:
- `:auto`
- `:required`
- `:none`
- tool name symbol/string or `ToolClass`

> With `:required` or specific tool choices, `tool_choice` is automatically reset to `nil` after tool execution to prevent infinite loops.
{: .note }

### "Parallel" Tool Calling (`calls`)

> Providers usually call this **parallel tool calling**. We call it `calls` because "parallel" can be misleading: tools are not executed in parallel unless RubyLLM is configured to run them concurrently. `calls` describes the actual behavior directly: `:many` means multiple tool calls in one assistant response, `:one` means one tool call in one assistant response.
{: .note }

Use `calls` to control how many tool calls the model may return in a single assistant response.

```ruby
chat.with_tools(Weather, Calculator, calls: :many)

chat.with_tools(Weather, Calculator, calls: :one)
# equivalent:
chat.with_tools(Weather, Calculator, calls: 1)
```

Valid values:
- `:many`
- `:one`
- `1`

If `calls` is not provided, RubyLLM uses provider/model defaults, which are usually equivalent to `calls: :many`.

> Tool choice and call-count controls are provider/model dependent.
{: .note }

## Concurrent Tool Execution

When a model returns multiple tool calls in one response, RubyLLM executes them sequentially by default. For I/O-bound tools, opt in to concurrent execution:

```ruby
chat.with_tools(Weather, StockPrice, Currency, concurrency: true)
```

`concurrency: true` uses Ruby threads and requires no extra dependencies. You can also choose a mode explicitly:

```ruby
chat.with_tools(Weather, StockPrice, Currency, concurrency: :threads)
chat.with_tools(Weather, StockPrice, Currency, concurrency: :fibers)
```

The `:fibers` mode uses the optional `async` gem:

```ruby
gem "async"
```

Enable concurrent tool execution globally:

```ruby
RubyLLM.configure do |config|
  config.tool_concurrency = true
end
```

Use `:threads`, `:fibers`, `true`, or `false`.

Override it per chat when needed:

```ruby
chat.with_tools(Weather, StockPrice, concurrency: false)
```

Rails chat records use the same setting and override:

```ruby
chat_record.with_tools(Weather, StockPrice, concurrency: false)
chat_record.with_tools(Weather, StockPrice, concurrency: :threads)
chat_record.with_tools(Weather, StockPrice, concurrency: :fibers)
```

With concurrency enabled, tool results are added back to the conversation as each tool finishes. RubyLLM waits
for all tool results before asking the model for the next response.

## Model Compatibility

RubyLLM will attempt to use tools with any model. If the model doesn't support function calling, the provider will return an appropriate error when you call `ask`.

## Monitoring Tool Calls with Callbacks

You can monitor tool execution using additive callbacks to track when tools are called and what they return. Available from v1.15+.

```ruby
chat = RubyLLM.chat(model: '{{ site.models.openai_tools }}')
      .with_tool(Weather)
      .before_tool_call do |tool_call|
        puts "Calling tool: #{tool_call.name}"
        puts "Arguments: #{tool_call.arguments}"
      end
      .after_tool_result do |result|
        puts "Tool returned: #{result}"
      end

response = chat.ask "What's the weather in Paris?"
# Output:
# Calling tool: weather
# Arguments: {"latitude": "48.8566", "longitude": "2.3522"}
# Tool returned: {"temperature": 15, "conditions": "Partly cloudy"}
```

These callbacks are useful for:
- **Logging and Analytics:** Track which tools are used most frequently
- **UI Updates:** Show loading states or progress indicators
- **Debugging:** Monitor tool inputs and outputs in production
- **Auditing:** Record tool usage for compliance or billing

### Example: Limiting Tool Calls

To prevent excessive API usage or infinite loops, you can use callbacks to limit tool calls:

```ruby
call_count = 0
max_calls = 10

chat = RubyLLM.chat(model: '{{ site.models.openai_tools }}')
      .with_tool(Weather)
      .before_tool_call do |tool_call|
        call_count += 1
        if call_count > max_calls
          raise "Tool call limit exceeded (#{max_calls} calls)"
        end
      end

chat.ask("Check weather for every major city...")
```

> Raising an exception in `before_tool_call` breaks the conversation flow - the LLM expects a tool response after requesting a tool call. This can leave the chat in an inconsistent state. Consider using better models or clearer tool descriptions to prevent loops instead of hard limits.
{: .warning }

## Next Steps

*   [Tool Parameters]({% link _core_features/tool-parameters.md %}) - Declare flat arguments, structured schemas, and provider-specific metadata.
*   [Tools]({% link _core_features/tools.md %}) - The execution flow, error handling, and security overview.
*   [Agentic Workflows]({% link _advanced/agentic-workflows.md %}#driving-the-loop-yourself) - Drive the tool loop yourself for full control.
*   [Chat Event Handlers]({% link _core_features/chat-callbacks.md %}) - Other lifecycle callbacks on a chat.

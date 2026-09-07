---
layout: default
title: Controlling Tool Execution
parent: "Tools"
nav_order: 2
description: Choose tools, require approval, run calls concurrently, and observe their results
---

# {{ page.title }}

{{ page.description }}
{: .fs-6 .fw-300 }

After reading this guide, you will know:

* How to control whether the model can call tools and which one.
* How to limit how many tool calls appear in one assistant response.
* How to require a human decision before a tool executes.
* How to run multiple tool calls concurrently for I/O-bound work.
* How to access the executing tool call from inside a tool.
* What happens when a model does not support function calling.
* How to observe tool calls and results with callbacks.
* How to cap tool usage to prevent runaway loops.

By default RubyLLM lets the model decide when to call tools and runs them sequentially. When you need tighter control, these options let you steer tool choice, parallelism, and observability per chat.

## Tool Call Controls

Use `choice:` to require or select a tool and `calls:` to limit how many calls the model returns in one response:

```ruby
chat.with_tools(Weather, Calculator)
chat.with_tool_options(choice: :required, calls: :one)
```

### Tool Choice

Use `choice` to control whether the model can call tools and which one it can call.

```ruby
# Model decides if a tool is needed
chat.with_tools(Weather, Calculator).with_tool_options(choice: :auto)

# Model must call a tool
chat.with_tools(Weather, Calculator).with_tool_options(choice: :required)

# Disable tool calls
chat.with_tools(Weather, Calculator).with_tool_options(choice: :none)

# Force one specific tool (symbol or class)
chat.with_tools(Weather, Calculator).with_tool_options(choice: :weather)
chat.with_tools(Weather, Calculator).with_tool_options(choice: Weather)
```

After a required or specific tool executes, RubyLLM clears that choice so the model can answer without calling it again.

### Calls Per Response

Use `calls` to control how many tool calls the model may return in a single assistant response.

```ruby
chat.with_tools(Weather, Calculator).with_tool_options(calls: :many)

chat.with_tools(Weather, Calculator).with_tool_options(calls: :one)
# equivalent:
chat.with_tools(Weather, Calculator).with_tool_options(calls: 1)
```

Without `calls:`, the provider's default applies. OpenAI and Anthropic honor `calls: :one`; Gemini can still return several calls. Multiple calls run sequentially unless you enable [concurrent execution](#concurrent-tool-execution).

### Clearing Tools and Options

Call `with_tools(nil)` to clear the attached tool list. It leaves the options set with `with_tool_options` in place; pass `nil` options to reset `choice`, `calls`, and `concurrency`:

```ruby
chat.with_tools(nil)       # forget the tools, keep the options
chat.with_tool_options(choice: nil, calls: nil, concurrency: nil) # reset all three
```

## Requiring Approval

Some tools should not run without a human decision: issuing refunds, deleting records, sending email. Declare them with `requires_approval` to pause execution until a decision is recorded:

```ruby
class IssueRefund < RubyLLM::Tool
  description "Issues a refund for an order"
  requires_approval

  def execute(order_id:)
    Refunds.issue!(order_id)
  end
end

chat = RubyLLM.chat.with_tools(IssueRefund)
response = chat.ask "Refund order 42"

chat.awaiting_approval? # => true, and nothing has executed
```

`complete` returns cleanly instead of running the tool. Record a decision, then continue the loop:

```ruby
tool_call = response.tool_calls.values.first

chat.approve(tool_call)
chat.complete # executes the tool, then lets the model continue
```

`approve` and `deny` accept a `ToolCall` or its id, and `chat.pending_approvals` lists the calls still waiting for a decision. A denied call never executes: the model receives a structured result saying the user denied the call, and the conversation continues from there.

```ruby
chat.deny(tool_call)
chat.complete # appends the denial result and asks the model to respond
```

Calls that need no approval still run while protected calls wait.

If you [drive the loop yourself]({% link _advanced/agentic-workflows.md %}#driving-the-loop-yourself), stop at pending approvals: `chat.step until chat.complete? || chat.awaiting_approval?`.

Finish the pending calls before asking another question. Otherwise `ask` raises `RubyLLM::PendingToolCallsError`.

To read decisions from your application, pass a resolver block. It receives the `ToolCall` and returns `true` to execute, `false` to deny, or `nil` while the decision is pending:

```ruby
class DeleteRecord < RubyLLM::Tool
  requires_approval { |tool_call| Approvals.status(tool_call.id) }
end
```

The resolver can run repeatedly while a call waits, including after a job resumes. Make it an idempotent read. If it creates an approval request, use a find-or-create operation.

### Remote Tool Approval

Providers can also request approval for a tool running on an MCP server. These requests appear in `chat.pending_approvals` with a `server` label. Use `approve`, `deny`, and `complete` as above; RubyLLM sends the decision to the provider instead of executing a Ruby tool. See [MCP servers]({% link _core_features/server-tools.md %}#remote-tool-approval) for a working example.

### Approval in Rails

With `acts_as_chat`, decisions persist on tool-call records. One process can request approval and another can resume execution. Use `chat.pending_approvals` to render each call's name and arguments in your approval UI.

After recording a decision, enqueue the job again. Load the chat through its agent class to restore the tools and approval rules:

```ruby
class MessagesController < ApplicationController
  def create
    chat = Chat.find(params[:chat_id])
    chat.ask_later(params[:message])
    CompleteJob.perform_later(chat.id)
  end
end

class ApprovalsController < ApplicationController
  def create
    chat = Chat.find(params[:chat_id])
    approved = ActiveModel::Type::Boolean.new.cast(params[:approved])
    approved ? chat.approve(params[:tool_call_id]) : chat.deny(params[:tool_call_id])
    CompleteJob.perform_later(chat.id)
  end
end

class CompleteJob < ApplicationJob
  def perform(chat_id)
    SupportAgent.find(chat_id).complete
  end
end
```

Write approval-gated tools so running them twice is safe. A tool execution can die after its side effect succeeds but before the result is persisted, and a retry will run it again.

[Durable Agents]({% link _advanced/durable-agents.md %}) covers jobs, restarts, and cancellation.

## Concurrent Tool Execution

When a model returns multiple tool calls in one response, RubyLLM executes them sequentially by default. For I/O-bound tools, opt in to concurrent execution:

```ruby
chat.with_tools(Weather, StockPrice, Currency).with_tool_options(concurrency: true)
```

`concurrency: true` uses Ruby threads and requires no extra dependencies. You can also choose a mode explicitly:

```ruby
chat.with_tools(Weather, StockPrice, Currency).with_tool_options(concurrency: :threads)
chat.with_tools(Weather, StockPrice, Currency).with_tool_options(concurrency: :fibers)
```

The `:fibers` mode uses the optional `async` gem:

```ruby
gem "async", ">= 2.0"
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
chat.with_tool_options(concurrency: false)
```

Rails chat records use the same settings.

With concurrency enabled, tool results are added back to the conversation as each tool finishes. RubyLLM waits
for all tool results before asking the model for the next response.

## Accessing the Current Tool Call

A tool sometimes needs to know which invocation triggered it, for example to attribute an audit log entry or an outbound API call to the exact tool call. Declare an optional `tool_call:` keyword on `execute` and RubyLLM fills it with the executing `ToolCall`:

```ruby
class SearchTool < RubyLLM::Tool
  description "Searches the knowledge base"
  parameter :query, description: "Search query"

  def execute(query:, tool_call: nil)
    AuditLog.create!(tool_call_id: tool_call&.id, tool_name: tool_call&.name)
    KnowledgeBase.search(query)
  end
end
```

`tool_call:` is reserved for RubyLLM and is not shown to the model. It also works during concurrent execution.

## Model Compatibility

RubyLLM will attempt to use tools with any model. If the model doesn't support function calling, the provider will return an appropriate error when you call `ask`.

## Monitoring Tool Calls with Callbacks

You can monitor tool execution using additive callbacks to track when tools are called and what they return.

```ruby
chat = RubyLLM.chat(model: '{{ site.models.openai_tools }}')
      .with_tools(Weather)
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


### Limiting Tool Calls

To cap a runaway loop, give the loop a step budget instead of raising inside a callback:

```ruby
chat = RubyLLM.chat(model: '{{ site.models.openai_tools }}')
              .with_tools(Weather)
              .ask_later("Check weather for every major city...")

10.times do
  chat.step
  break if chat.complete?
end
```

When the budget runs out the transcript is still valid, and calling `step` again resumes where it stopped. See [Driving the Loop Yourself]({% link _advanced/agentic-workflows.md %}#driving-the-loop-yourself).

## Next Steps

*   [Tool Parameters]({% link _core_features/tool-parameters.md %}) - Declare flat arguments, structured schemas, and provider-specific metadata.
*   [Tools]({% link _core_features/tools.md %}) - The execution flow, error handling, and security overview.
*   [Agentic Workflows]({% link _advanced/agentic-workflows.md %}#driving-the-loop-yourself) - Drive the tool loop yourself for full control.
*   [Chat Event Handlers]({% link _core_features/chat-callbacks.md %}) - Other lifecycle callbacks on a chat.

---
layout: default
title: Chat Event Handlers
nav_order: 9
description: Hook into the chat lifecycle with additive callbacks for UI updates, logging, and analytics
---

# {{ page.title }}

{{ page.description }}
{: .fs-6 .fw-300 }

After reading this guide, you will know:

* Which lifecycle events you can register handlers for.
* Why callbacks are additive.
* How chat callbacks differ from retry- and cancellation-safe usage instrumentation.
* How to observe tool calls, their progress, and tool results as they happen.
* How to run each tool inside a block, such as a tenant or `Current` attributes.
* How to observe messages as they are queued, join the conversation, or are withdrawn.
* How to observe model fallback attempts.
* When callbacks fire for streaming versus non-streaming requests.

Use callbacks to update a UI, log tool activity, or observe model fallbacks. They use the same `before_` and `after_` naming as Rails callbacks.

To replace files a protocol cannot send, use `convert_unsupported_attachments`. See [Converting Unsupported Attachments]({% link _core_features/attachments.md %}#converting-unsupported-attachments) for its return values and how it preserves the original conversation.

## Message Events

```ruby
chat = RubyLLM.chat
chat.before_message { print "Assistant > " }
chat.after_message { |message| puts message.content }

chat.ask "What is metaprogramming in Ruby?"
```

Message callbacks run for assistant responses and tool results, with or without streaming. They are additive: registering a second block keeps the first, along with RubyLLM's own persistence callbacks.

## Tool Events

Show which tools the model calls and what they return:

```ruby
chat.before_tool_call do |call|
  puts "Calling #{call.name} with #{call.arguments}"
end

chat.after_tool_result do |result|
  puts "Tool returned: #{result}"
end
```

A slow tool can report what it is doing before its result arrives:

```ruby
chat.after_tool_progress do |call, progress|
  puts "#{call.name}: #{progress.message}"
end
```

See [Reporting Progress]({% link _tools/tool-execution.md %}#reporting-progress).

### Wrapping Tool Calls

`around_tool_call` runs each tool inside your block, like a Rails `around_action`. Call `run` where the tool should run:

```ruby
chat.around_tool_call do |call, &run|
  ActsAsTenant.with_tenant(account, &run)
end
```

The block runs in the thread or fiber that runs the tool, so a tenant, `Current` attributes, or fiber-local values you set there reach the tool, also with [concurrent tool execution]({% link _tools/tool-execution.md %}#concurrent-tool-execution). `run` returns the tool's result, and the conversation gets that result whatever your block returns. A block that never calls `run` skips the tool, and the model is told the call did not run.

It runs after `before_tool_call` and before `after_tool_result`. Several blocks nest in the order you registered them, the first outermost.

## Queue Events

[Queued messages]({% link _advanced/agentic-workflows.md %}#queueing-messages) wait outside the conversation until the loop takes them. One that joins becomes an ordinary user message, and `after_message` receives it in the loop's thread, before `before_message` runs for the reply that answers it:

```ruby
chat.after_message do |message|
  puts "Joined: #{message.content}" if message.role == :user
end
```

To act at the moment a message joins, or to withdraw it instead, wrap the join with `around_join`. It receives the queued message and `join`. See [Joining Queued Messages]({% link _advanced/agentic-workflows.md %}#joining-queued-messages).

## Fallback Events

```ruby
chat.before_fallback do |fallback|
  puts "Trying #{fallback.to.id} after #{fallback.from.id} failed"
end

chat.after_fallback do |fallback|
  puts "#{fallback.to.id}: #{fallback.succeeded? ? "succeeded" : "failed"}"
end
```

`before_fallback` runs before each fallback attempt; `after_fallback` runs after it succeeds or fails. Both receive a `RubyLLM::Fallback` with `from`, `to`, `error`, `attempt`, `response`, `fallback_error`, `streaming?`, and `chunks_yielded?`.

## Usage Events

`after_message` observes transcript changes, including the partial reply a cancelled stream keeps. A cancelled request may produce no message, so use `usage.ruby_llm` for accounting across provider attempts, including retries and cancellations. See [Cost and Usage Tracking]({% link _core_features/cost-and-usage-tracking.md %}) and [Instrumentation]({% link _advanced/instrumentation.md %}).

## Next Steps

* [Chat]({% link _getting_started/chat.md %}) - the core conversation interface these events fire on.
* [Streaming]({% link _core_features/streaming.md %}) - stream chunks as the assistant generates them.
* [Cost and Usage Tracking]({% link _core_features/cost-and-usage-tracking.md %}) - observe provider attempts independently from messages.
* [Tools]({% link _getting_started/tools.md %}) - define the tools whose calls and results these callbacks observe.
* [Error Handling]({% link _advanced/error-handling.md %}#model-fallbacks) - configure model fallbacks and fallback error handling.
* [Rails Integration]({% link _getting_started/rails.md %}) - see how persistence callbacks run alongside your own.

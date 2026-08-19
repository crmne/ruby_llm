---
layout: default
title: Chat Event Handlers
parent: "Chat"
nav_order: 10
description: Hook into the chat lifecycle with additive callbacks for UI updates, logging, and analytics
---

# {{ page.title }}

{{ page.description }}
{: .fs-6 .fw-300 }

After reading this guide, you will know:

* Which lifecycle events you can register handlers for.
* Why callbacks are additive and what replaced the 1.x `on_*` handlers.
* How chat callbacks differ from retry- and cancellation-safe usage instrumentation.
* How to observe tool calls and tool results as they happen.
* How to observe model fallback attempts.
* When callbacks fire for streaming versus non-streaming requests.

You can register blocks to be called when certain events occur during the chat lifecycle. This is particularly useful for UI updates, logging, analytics, or building real-time chat interfaces.

## Available Event Handlers

Callbacks are Rails-style and additive: register as many blocks as you like for the same event and they all run, alongside RubyLLM's own bookkeeping such as the Rails persistence callbacks.

```ruby
chat = RubyLLM.chat

# Called before each assistant response or tool result is appended
chat.before_message do
  print "Assistant > "
end

# Called after each assistant response or tool result message is appended
chat.after_message do |message|
  puts "Response complete!"
  if message.tokens.output
    tokens =
      message.tokens.input.to_i +
      message.tokens.output.to_i +
      message.tokens.cache_read.to_i +
      message.tokens.cache_write.to_i

    puts "Used #{tokens} tokens"
  end
end

# Called when the AI decides to use a tool
chat.before_tool_call do |tool_call|
  puts "AI is calling tool: #{tool_call.name} with arguments: #{tool_call.arguments}"
end

# Called after a tool returns its result
chat.after_tool_result do |result|
  puts "Tool returned: #{result}"
end

# Called before RubyLLM tries a fallback model
chat.before_fallback do |fallback|
  puts "Falling back from #{fallback.from.id} to #{fallback.to.id}"
end

# Called after a fallback model succeeds or fails
chat.after_fallback do |fallback|
  puts "Fallback #{fallback.succeeded? ? 'succeeded' : 'failed'}"
end

# Message callbacks work for both streaming and non-streaming requests
chat.ask "What is metaprogramming in Ruby?"
```

Fallback callbacks run around each fallback attempt. `before_fallback` fires after the current model fails and before RubyLLM tries the fallback model. `after_fallback` fires when that fallback attempt succeeds or fails. The callback receives a `RubyLLM::Fallback` with `from`, `to`, `error`, `attempt`, `response`, `fallback_error`, `streaming?`, and `chunks_yielded?`.

`after_message` observes transcript changes. It cannot observe a cancelled attempt that produces no message. Subscribe to `usage.ruby_llm` when you need cost and usage events; it fires once per physical provider attempt, including retries and cancellations. See [Cost and Usage Tracking]({% link _core_features/cost-and-usage-tracking.md %}).

The 1.x handlers (`on_new_message`, `on_end_message`, `on_tool_call`, `on_tool_result`), which replaced each other on re-registration, were removed in 2.0.

## Next Steps

* [Chat]({% link _core_features/chat.md %}) - the core conversation interface these events fire on.
* [Streaming]({% link _core_features/streaming.md %}) - stream chunks as the assistant generates them.
* [Cost and Usage Tracking]({% link _core_features/cost-and-usage-tracking.md %}) - observe provider attempts independently from messages.
* [Tools]({% link _core_features/tools.md %}) - define the tools whose calls and results these callbacks observe.
* [Error Handling]({% link _advanced/error-handling.md %}#model-fallbacks) - configure model fallbacks and fallback error handling.
* [Rails Integration]({% link _advanced/rails.md %}) - see how persistence callbacks run alongside your own.

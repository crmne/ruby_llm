---
layout: default
title: Chat Event Handlers
parent: "Chat"
nav_order: 8
description: Hook into the chat lifecycle with additive callbacks for UI updates, logging, and analytics
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

* Which lifecycle events you can register handlers for.
* How the `before_*` and `after_*` callbacks differ from the older `on_*` handlers.
* How to read token usage inside an `after_message` callback.
* How to observe tool calls and tool results as they happen.
* When callbacks fire for streaming versus non-streaming requests.

## Chat Event Handlers

You can register blocks to be called when certain events occur during the chat lifecycle. This is particularly useful for UI updates, logging, analytics, or building real-time chat interfaces.

### Available Event Handlers

RubyLLM provides two callback styles. The `on_*` handlers replace any previously registered handler for the same event, which is useful when you want to override behavior. The Rails-style `before_*` and `after_*` callbacks are additive, so multiple registrations for the same event all run. Additive callbacks are available from v1.15+.

```ruby
chat = RubyLLM.chat

# Called at first chunk received from the assistant
chat.before_message do
  print "Assistant > "
end

# Called after the complete assistant message (including tool calls/results) is received
chat.after_message do |message|
  puts "Response complete!"
  # Note: message might be nil if an error occurred during the request
  if message&.tokens&.output
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

# These callbacks work for both streaming and non-streaming requests
chat.ask "What is metaprogramming in Ruby?"
```

Each callback is additive - register as many as you like, and they run alongside RubyLLM's own bookkeeping (such as the Rails persistence callbacks). The older replacing handlers (`on_new_message`, `on_end_message`, `on_tool_call`, `on_tool_result`) were removed in 2.0.

## Next Steps

* [Chat]({% link _core_features/chat.md %}) - the core conversation interface these events fire on.
* [Streaming]({% link _core_features/streaming.md %}) - stream chunks as the assistant generates them.
* [Tools]({% link _core_features/tools.md %}) - define the tools whose calls and results these callbacks observe.
* [Rails Integration]({% link _advanced/rails.md %}) - see how persistence callbacks run alongside your own.

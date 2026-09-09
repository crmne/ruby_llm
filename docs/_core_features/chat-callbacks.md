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

Use callbacks to update a UI, log tool activity, or observe model fallbacks. They use the same `before_` and `after_` naming as Rails callbacks.

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

## Fallback Events

```ruby
chat.before_fallback do |fallback|
  puts "Trying #{fallback.to.id} after #{fallback.from.id} failed"
end

chat.after_fallback do |fallback|
  puts "#{fallback.to.id}: #{fallback.succeeded? ? 'succeeded' : 'failed'}"
end
```

`before_fallback` runs before each fallback attempt; `after_fallback` runs after it succeeds or fails. Both receive a `RubyLLM::Fallback` with `from`, `to`, `error`, `attempt`, `response`, `fallback_error`, `streaming?`, and `chunks_yielded?`.

## Usage Events

`after_message` observes transcript changes. A cancelled request may produce no message, so use `usage.ruby_llm` for accounting across provider attempts, including retries and cancellations. See [Cost and Usage Tracking]({% link _core_features/cost-and-usage-tracking.md %}) and [Instrumentation]({% link _advanced/instrumentation.md %}).

The 1.x `on_*` handlers were replaced in 2.0. See [Upgrading]({% link _reference/upgrading.md %}#chat-callbacks) for the name changes.

## Next Steps

* [Chat]({% link _core_features/chat.md %}) - the core conversation interface these events fire on.
* [Streaming]({% link _core_features/streaming.md %}) - stream chunks as the assistant generates them.
* [Cost and Usage Tracking]({% link _core_features/cost-and-usage-tracking.md %}) - observe provider attempts independently from messages.
* [Tools]({% link _core_features/tools.md %}) - define the tools whose calls and results these callbacks observe.
* [Error Handling]({% link _advanced/error-handling.md %}#model-fallbacks) - configure model fallbacks and fallback error handling.
* [Rails Integration]({% link _advanced/rails.md %}) - see how persistence callbacks run alongside your own.

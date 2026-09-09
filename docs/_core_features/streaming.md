---
layout: default
title: Stream Responses
parent: "Chat"
nav_order: 2
description: Learn how to display AI responses in real-time as they're generated
redirect_from:
  - /guides/streaming
---

# {{ page.title }}

{{ page.description }}
{: .fs-6 .fw-300 }

After reading this guide, you will know:

*   How to initiate a streaming chat request.
*   How to process the streamed `Chunk` objects.
*   How the final accumulated message is handled.
*   How to integrate streaming with web frameworks like Rails and Sinatra.
*   How streaming interacts with Tools.
*   Performance considerations for streaming.

## Basic Streaming

To stream responses, provide a block to the `ask` method on a `Chat` object.

```ruby
chat = RubyLLM.chat

puts "Assistant:"
chat.ask "Write a short story about an adventurous ruby gem." do |chunk|
  print chunk.content # Print content fragment immediately
end
# => (Output appears incrementally) Once upon a time, in the vast digital...
```

RubyLLM normalizes different provider streaming formats (like Server-Sent Events) into standardized `Chunk` objects.

## Understanding Chunks

Each object yielded to the block is an instance of `RubyLLM::Chunk`, which inherits from `RubyLLM::Message`. It contains the partial information received in that specific part of the stream.

Key attributes of a `Chunk`:

*   `chunk.content`: The text fragment received in this chunk (can be `nil` or empty for some chunks, especially those containing only metadata or tool calls).
*   `chunk.role`: Always `:assistant` for streamed response chunks.
*   `chunk.model`: The model generating the response (usually present).
*   `chunk.tool_calls`: A hash containing partial or complete tool call information if the model is invoking a [Tool]({% link _core_features/tools.md %}). The arguments might be streamed incrementally.
*   `chunk.tokens.input`: Standard input tokens for the request (often `nil` until the final chunk). Cache reads and writes are exposed separately as `chunk.tokens.cache_read` and `chunk.tokens.cache_write` when providers report them.
*   `chunk.tokens.output`: Cumulative billable output tokens *up to this chunk* (behavior varies by provider, often only accurate in the final chunk). Includes thinking/reasoning tokens when the provider bills them as output.
*   `chunk.thinking`: Optional thinking output when providers stream it.
*   `chunk.finish_reason`: Provider-reported reason the model stopped, usually only present on the final chunk. Chunks also support finish-reason predicates such as `chunk.max_tokens?`, `chunk.content_filtered?`, `chunk.tool_call_stop?`, and `chunk.stopped?`.

> Do not rely on token counts being present or accurate in every chunk. They are typically finalized only in the last chunk or the final returned message.
{: .warning }

## Accumulated Response

`ask` returns the completed message after streaming, including any tool interactions:

```ruby
response = chat.ask "Write a short haiku about programming." do |chunk|
  print chunk.content
end

response.content
response.tokens.output
response.cost.total
response.finish_reason
```

Use the chunks for live display and the returned message for the final text and usage.

## Web Application Integration

Streaming is particularly useful in web applications for providing immediate feedback.

### Rails with Turbo Streams

With Rails persistence installed, generate a streaming chat UI:

```bash
bin/rails generate ruby_llm:chat_ui
```

The generator writes a controller, an Active Job, and Turbo Stream views into your application. [Streaming with Hotwire/Turbo]({% link _advanced/rails-streaming.md %}) shows the complete implementation, including broadcasting chunks to persisted messages.

### Sinatra with Server-Sent Events (SSE)

SSE is a natural fit for streaming text responses.

```ruby
require 'sinatra'
require 'ruby_llm'
# ... configuration ...

get '/stream_chat' do
  content_type 'text/event-stream'
  stream(:keep_open) do |out|
    chat = RubyLLM.chat
    begin
      chat.ask(params[:prompt] || "Tell me a fun fact.") do |chunk|
        out << "data: #{chunk.content.to_json}\n\n" if chunk.content
      end
      out << "event: complete\ndata: {}\n\n"
    rescue => e
      out << "event: error\ndata: #{ { error: e.message }.to_json }\n\n"
    ensure
      out.close
    end
  end
end
```

## Cancelling a Stream

Call `cancel` to stop the current in-flight chat operation. RubyLLM checks for cancellation before model requests, before tool execution, and while streaming chunks. When cancellation is observed, it raises `RubyLLM::CancelledError` and clears the cancellation flag so the chat can be reused.

```ruby
chat = RubyLLM.chat

begin
  chat.ask("Write a long report") do |chunk|
    print chunk.content
    chat.cancel if should_stop?
  end
rescue RubyLLM::CancelledError
  puts "Generation cancelled"
end
```

With `acts_as_chat`, `cancel` records the cancellation in the chat record's `cancelled` column. That lets a controller stop a generation running in a background job:

```ruby
# app/controllers/chats_controller.rb
def cancel
  Chat.find(params[:id]).cancel
  head :no_content
end

# app/jobs/chat_stream_job.rb
def perform(chat_id)
  chat = Chat.find(chat_id)
  chat.complete { |chunk| broadcast(chunk) }
rescue RubyLLM::CancelledError
  # Optionally broadcast a cancelled state.
end
```

## Error Handling During Streaming

Errors (like network issues, rate limits, or provider errors) can occur mid-stream. The `ask` method will raise the appropriate `RubyLLM::Error` subclass after the block execution finishes or is interrupted by the error.

```ruby
begin
  chat = RubyLLM.chat
  puts "Assistant:"
  chat.ask("Generate a very long response...") do |chunk|
    print chunk.content
  end
rescue RubyLLM::Error => e
  puts "\n--- Error during streaming ---"
  puts "Error Type: #{e.class}"
  puts "Message: #{e.message}"
  # Check e.response for more details if needed
end
```

Refer to the [Error Handling Guide]({% link _advanced/error-handling.md %}) for details on specific error types.

## Streaming with Tools

Your streaming block can keep displaying text while RubyLLM runs tools between model responses. Use a callback to show tool activity:

```ruby
chat = RubyLLM.chat.with_tools(Weather)
chat.before_tool_call { |call| puts "\nCalling #{call.name}..." }

chat.ask "What's the weather in Berlin? Latitude 52.52, longitude 13.40." do |chunk|
  print chunk.content
end
```

`Weather` is defined in the [Tools guide]({% link _core_features/tools.md %}#creating-a-tool). Tool-call arguments can arrive in partial chunks, so use callbacks when you need the complete call. See [Chat Event Handlers]({% link _core_features/chat-callbacks.md %}).

## Next Steps

*   [Using Tools]({% link _core_features/tools.md %})
*   [Rails Integration]({% link _advanced/rails.md %})
*   [Error Handling]({% link _advanced/error-handling.md %})

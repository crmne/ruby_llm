---
layout: default
title: Streaming
parent: Guides
nav_order: 4
permalink: /guides/streaming
---

# Streaming Responses

RubyLLM provides streaming capabilities that allow you to receive AI responses in real-time as they're being generated, rather than waiting for the complete response. This creates a more interactive experience and is especially useful for long responses or applications with real-time UI updates.

## Basic Streaming

To stream responses, simply provide a block to the `ask` method:

```ruby
chat = RubyLLM.chat

chat.ask "Write a short story about a programmer" do |chunk|
  # Each chunk contains a portion of the response
  print chunk.content
end
```

## Understanding Chunks

Each streamed chunk is an instance of `RubyLLM::Chunk` (which inherits from `RubyLLM::Message`) and provides:

```ruby
chunk.content       # The text fragment in this chunk
chunk.role          # Always :assistant for streamed chunks
chunk.model_id      # The model generating the response
chunk.input_tokens  # Input token count (usually only in the final chunk)
chunk.output_tokens # Output token count (usually only in the final chunk)
```

## Accumulated Response

Even when streaming, RubyLLM still returns the complete final message:

```ruby
final_message = chat.ask "Write a poem" do |chunk|
  print chunk.content
end

# You can use the final message as normal
puts "\nFinal message length: #{final_message.content.length}"
puts "Token usage: #{final_message.output_tokens} tokens"
```

## Web Application Integration

### Rails with Turbo Streams

```ruby
class ChatJob < ApplicationJob
  queue_as :default

  def perform(chat_id, message)
    chat = Chat.find(chat_id)

    chat.ask(message) do |chunk|
      Turbo::StreamsChannel.broadcast_update_to(
        "chat_#{chat.id}",
        target: "response",
        html: chunk.content,
        append: true
      )
    end
  end
end
```

### Sinatra with Server-Sent Events (SSE)

```ruby
get '/chat/:id/ask' do
  content_type 'text/event-stream'

  chat = Chat.find(params[:id])

  chat.ask(params[:message]) do |chunk|
    # Send chunk as SSE event
    out << "data: #{chunk.content}\n\n"
  end

  # Send completion signal
  out << "event: complete\ndata: {}\n\n"
end
```

## Error Handling

Errors that occur during streaming need special handling:

```ruby
begin
  chat.ask("Tell me a story") do |chunk|
    print chunk.content
  end
rescue RubyLLM::Error => e
  puts "\nError during streaming: #{e.message}"
end
```

Common errors during streaming:

- `ServiceUnavailableError` - The AI service is temporarily unavailable
- `RateLimitError` - You've exceeded your API rate limit
- `BadRequestError` - There was a problem with your request parameters

## Provider-Specific Considerations

### OpenAI

OpenAI's streaming implementation provides small, frequent chunks for a smooth experience.

### Anthropic

Claude models may return slightly larger chunks with potentially longer pauses between them.

### Google Gemini

Gemini streaming is highly responsive but may show slightly different chunking behavior.

## Streaming with Tools

When using tools, streaming works a bit differently:

```ruby
chat.with_tool(Calculator)
   .ask("What's 123 * 456?") do |chunk|
     # Tool call execution isn't streamed
     # You'll receive chunks after tool execution completes
     print chunk.content
   end
```

The tool call execution introduces a pause in the streaming, as the model waits for the tool response before continuing.

## Performance Considerations

Streaming typically uses the same number of tokens as non-streaming responses but establishes longer-lived connections to the AI provider. Consider these best practices:

1. Set appropriate timeouts for streaming connections
2. Handle network interruptions gracefully
3. Consider background processing for long-running streams
4. Implement rate limiting to avoid overwhelming your servers

## Tracking Token Usage

Token usage information is typically only available in the final chunk or completed message:

```ruby
total_tokens = 0

chat.ask("Write a detailed explanation of quantum computing") do |chunk|
  print chunk.content

  # Only count tokens in the final chunk
  if chunk.output_tokens
    total_tokens = chunk.input_tokens + chunk.output_tokens
  end
end

puts "\nTotal tokens: #{total_tokens}"
```

## Custom Processing of Streamed Content

You can process streamed content in real-time:

```ruby
accumulated_text = ""

chat.ask("Write a list of 10 fruits") do |chunk|
  new_content = chunk.content
  accumulated_text += new_content

  # Count fruits as they come in
  if new_content.include?("\n")
    fruit_count = accumulated_text.scan(/\d+\./).count
    print "\rFruits listed: #{fruit_count}/10"
  end
end
```

## Rails Integration

When using RubyLLM's Rails integration with `acts_as_chat`, streaming still works seamlessly:

```ruby
class Chat < ApplicationRecord
  acts_as_chat
end

chat = Chat.create!(model_id: 'gpt-4o-mini')

# Stream responses while persisting the final result
chat.ask("Tell me about Ruby") do |chunk|
  ActionCable.server.broadcast("chat_#{chat.id}", { content: chunk.content })
end

# The complete message is saved in the database
puts chat.messages.last.content
```

## Next Steps

Now that you understand streaming, you might want to explore:

- [Using Tools]({% link guides/tools.md %}) to add capabilities to your AI interactions
- [Rails Integration]({% link guides/rails.md %}) to persist conversations
- [Error Handling]({% link guides/error-handling.md %}) for reliable applications
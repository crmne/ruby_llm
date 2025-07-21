---
layout: default
title: Chatting with AI Models
parent: Guides
nav_order: 2
permalink: /guides/chat
---

# Chatting with AI Models
{: .no_toc }

The heart of RubyLLM is the `Chat` object, providing a unified and intuitive interface for conversational interactions with various AI models.
{: .fs-6 .fw-300 }

## Table of contents
{: .no_toc .text-delta }

1. TOC
{:toc}

---

After reading this guide, you will know:

*   How to start and continue conversations.
*   How to use system prompts (instructions) to guide the AI.
*   How to select specific models and providers.
*   How to interact with models using images, audio, and PDFs.
*   How to control response creativity using temperature.
*   How to track token usage.
*   How to use chat event handlers.

## Starting a Conversation

The simplest way to begin is with `RubyLLM.chat`, which creates a `Chat` instance using the configured default model (often a capable OpenAI GPT model).

```ruby
chat = RubyLLM.chat

# The ask method sends a user message and returns the assistant's response
response = chat.ask "Explain the concept of 'Convention over Configuration' in Rails."

# The response is a RubyLLM::Message object
puts response.content
# => "Convention over Configuration (CoC) is a core principle of Ruby on Rails..."

# The response object contains metadata
puts "Model Used: #{response.model_id}"
puts "Tokens Used: #{response.input_tokens} input, #{response.output_tokens} output"
```

The `ask` method (aliased as `say`) adds your message to the conversation history with the `:user` role and then triggers a request to the AI provider. The returned `RubyLLM::Message` object represents the assistant's reply.

## Continuing the Conversation

The `Chat` object maintains the conversation history. Subsequent calls to `ask` build upon the previous messages.

```ruby
# Continuing the previous chat...
response = chat.ask "Can you give a specific example in Rails?"
puts response.content
# => "Certainly! A classic example is database table naming..."

# Access the full conversation history
chat.messages.each do |message|
  puts "[#{message.role.to_s.upcase}] #{message.content.lines.first.strip}"
end
# => [USER] Explain the concept of 'Convention over Configuration' in Rails.
# => [ASSISTANT] Convention over Configuration (CoC) is a core principle...
# => [USER] Can you give a specific example in Rails?
# => [ASSISTANT] Certainly! A classic example is database table naming...
```

Each call to `ask` sends the *entire* current message history (up to the model's context limit) to the provider, allowing the AI to understand the context of your follow-up questions.

## Guiding the AI with Instructions

You can provide instructions, also known as system prompts, to guide the AI's behavior, persona, or response format throughout the conversation. Use the `with_instructions` method.

```ruby
chat = RubyLLM.chat

# Set the initial instruction
chat.with_instructions "You are a helpful assistant that explains Ruby concepts simply, like explaining to a five-year-old."

response = chat.ask "What is a variable?"
puts response.content
# => "Imagine you have a special box, and you can put things in it..."

# Use replace: true to ensure only the latest instruction is active
chat.with_instructions "Always end your response with 'Got it?'", replace: true

response = chat.ask "What is a loop?"
puts response.content
# => "A loop is like singing your favorite song over and over again... Got it?"
```

Instructions are prepended to the conversation history as messages with the `:system` role. They are particularly useful for setting a consistent tone or providing context the AI should always consider. If you are using the [Rails Integration]({% link guides/rails.md %}), these system messages are persisted along with user and assistant messages.

## Selecting Models and Providers

While `RubyLLM.chat` uses the default model, you can easily specify a different one.

```ruby
# Use a specific model via ID or alias
chat_claude = RubyLLM.chat(model: 'claude-3-5-sonnet')
chat_gemini = RubyLLM.chat(model: 'gemini-1.5-pro-latest')

# Change the model on an existing chat instance
chat = RubyLLM.chat(model: 'gpt-4.1-nano')
response1 = chat.ask "Initial question for GPT..."
puts response1.content

response2 = chat.with_model('claude-3-opus-20240229').ask("Follow-up question for Claude...")
puts response2.content
```

RubyLLM manages a registry of known models and their capabilities. For detailed information on finding models, using aliases, checking capabilities, and working with custom or unlisted models (using `assume_model_exists: true`), please refer to the **[Working with Models Guide]({% link guides/models.md %})**.

## Multi-modal Conversations

Modern AI models can often process more than just text. RubyLLM provides a unified way to include images, audio, text files, and PDFs in your chat messages using the `with:` option in the `ask` method.

### Working with Images

Provide image paths or URLs to vision-capable models (like `gpt-4o`, `claude-3-opus`, `gemini-1.5-pro`).

```ruby
# Ensure you select a vision-capable model
chat = RubyLLM.chat(model: 'gpt-4o')

# Ask about a local image file
response = chat.ask "Describe this logo.", with: "path/to/ruby_logo.png"
puts response.content

# Ask about an image from a URL
response = chat.ask "What kind of architecture is shown here?", with: "https://example.com/eiffel_tower.jpg"
puts response.content

# Send multiple images
response = chat.ask "Compare the user interfaces in these two screenshots.", with: ["screenshot_v1.png", "screenshot_v2.png"]
puts response.content
```

RubyLLM handles converting the image source into the format required by the specific provider API.

### Working with Audio

Provide audio file paths to audio-capable models (like `gpt-4o-audio-preview`).

```ruby
chat = RubyLLM.chat(model: 'gpt-4o-audio-preview') # Use an audio-capable model

# Transcribe or ask questions about audio content
response = chat.ask "Please transcribe this meeting recording.", with: "path/to/meeting.mp3"
puts response.content

# Ask follow-up questions based on the audio context
response = chat.ask "What were the main action items discussed?"
puts response.content
```

### Working with Text Files

Provide text file paths to models that support document analysis.

```ruby
chat = RubyLLM.chat(model: 'claude-3-5-sonnet')

# Analyze a text file
response = chat.ask "Summarize the key points in this document.", with: "path/to/document.txt"
puts response.content

# Ask questions about code files
response = chat.ask "Explain what this Ruby file does.", with: "app/models/user.rb"
puts response.content
```

### Working with PDFs

Provide PDF paths or URLs to models that support document analysis (currently Claude 3+ and Gemini models).

```ruby
# Use a model that supports PDFs
chat = RubyLLM.chat(model: 'claude-3-7-sonnet')

# Ask about a local PDF
response = chat.ask "Summarize the key findings in this research paper.", with: "path/to/paper.pdf"
puts response.content

# Ask about a PDF via URL
response = chat.ask "What are the terms and conditions outlined here?", with: "https://example.com/terms.pdf"
puts response.content

# Combine text and PDF context
response = chat.ask "Based on section 3 of this document, what is the warranty period?", with: "manual.pdf"
puts response.content
```

{: .note }
**PDF Limitations:** Be mindful of provider-specific limits. For example, Anthropic Claude models currently have a 10MB per-file size limit, and the total size/token count of all PDFs must fit within the model's context window (e.g., 200,000 tokens for Claude 3 models).

### Simplified Attachment API

RubyLLM automatically detects file types based on extensions and content, so you can pass files directly without specifying the type:

```ruby
chat = RubyLLM.chat(model: 'claude-3-5-sonnet')

# Single file - type automatically detected
response = chat.ask "What's in this file?", with: "path/to/document.pdf"

# Multiple files of different types
response = chat.ask "Analyze these files", with: [
  "diagram.png",
  "report.pdf",
  "meeting_notes.txt",
  "recording.mp3"
]

# Still works with the explicit hash format if needed
response = chat.ask "What's in this image?", with: { image: "photo.jpg" }
```

**Supported file types:**
- **Images:** .jpg, .jpeg, .png, .gif, .webp, .bmp
- **Audio:** .mp3, .wav, .m4a, .ogg, .flac
- **Documents:** .pdf, .txt, .md, .csv, .json, .xml
- **Code:** .rb, .py, .js, .html, .css (and many others)

## Controlling Creativity: Temperature

The `temperature` setting influences the randomness and creativity of the AI's responses. A higher value (e.g., 0.9) leads to more varied and potentially surprising outputs, while a lower value (e.g., 0.1) makes the responses more focused, deterministic, and predictable. The default is generally around 0.7.

```ruby
# Create a chat with low temperature for factual answers
factual_chat = RubyLLM.chat.with_temperature(0.2)
response1 = factual_chat.ask "What is the boiling point of water at sea level in Celsius?"
puts response1.content

# Create a chat with high temperature for creative writing
creative_chat = RubyLLM.chat.with_temperature(0.9)
response2 = creative_chat.ask "Write a short poem about the color blue."
puts response2.content
```

You can set the temperature using `with_temperature`, which returns the `Chat` instance for chaining.

## Custom Request Parameters (`with_params`)
{: .d-inline-block }

Available in v1.4.0
{: .label .label-yellow }

You can configure additional provider-specific features by adding custom fields to each API request. Use the `with_params` method.

```ruby
# response_format parameter is supported by :openai, :ollama, :deepseek
chat = RubyLLM.chat.with_params(response_format: { type: 'json_object' })
response = chat.ask "What is the square root of 64? Answer with a JSON object with the key `result`."
puts JSON.parse(response.content)
```

Allowed parameters vary widely by provider and model. Please consult the provider's documentation.

## Tracking Token Usage

Understanding token usage is important for managing costs and staying within context limits. Each `RubyLLM::Message` returned by `ask` includes token counts.

```ruby
response = chat.ask "Explain the Ruby Global Interpreter Lock (GIL)."

input_tokens = response.input_tokens   # Tokens in the prompt sent TO the model
output_tokens = response.output_tokens # Tokens in the response FROM the model

puts "Input Tokens: #{input_tokens}"
puts "Output Tokens: #{output_tokens}"
puts "Total Tokens for this turn: #{input_tokens + output_tokens}"

# Estimate cost for this turn
model_info = RubyLLM.models.find(response.model_id)
if model_info.input_price_per_million && model_info.output_price_per_million
  input_cost = input_tokens * model_info.input_price_per_million / 1_000_000
  output_cost = output_tokens * model_info.output_price_per_million / 1_000_000
  turn_cost = input_cost + output_cost
  puts "Estimated Cost for this turn: $#{format('%.6f', turn_cost)}"
else
  puts "Pricing information not available for #{model_info.id}"
end

# Total tokens for the entire conversation so far
total_conversation_tokens = chat.messages.sum { |msg| (msg.input_tokens || 0) + (msg.output_tokens || 0) }
puts "Total Conversation Tokens: #{total_conversation_tokens}"
```

Refer to the [Working with Models Guide]({% link guides/models.md %}) for details on accessing model-specific pricing.

## Chat Event Handlers

You can register blocks to be called when certain events occur during the chat lifecycle, useful for UI updates or logging.

```ruby
chat = RubyLLM.chat

# Called just before the API request for an assistant message starts
chat.on_new_message do
  puts "Assistant is typing..."
end

# Called after the complete assistant message (including tool calls/results) is received
chat.on_end_message do |message|
  puts "Response complete!"
  # Note: message might be nil if an error occurred during the request
  if message && message.output_tokens
    puts "Used #{message.input_tokens + message.output_tokens} tokens"
  end
end

# These callbacks work for both streaming and non-streaming requests
chat.ask "What is metaprogramming in Ruby?"
```

## Next Steps

This guide covered the core `Chat` interface. Now you might want to explore:

*   [Working with Models]({% link guides/models.md %}): Learn how to choose the best model and handle custom endpoints.
*   [Using Tools]({% link guides/tools.md %}): Enable the AI to call your Ruby code.
*   [Streaming Responses]({% link guides/streaming.md %}): Get real-time feedback from the AI.
*   [Rails Integration]({% link guides/rails.md %}): Persist your chat conversations easily.
*   [Error Handling]({% link guides/error-handling.md %}): Build robust applications that handle API issues.

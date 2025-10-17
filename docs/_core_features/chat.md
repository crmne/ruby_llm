---
layout: default
title: Chat
nav_order: 1
description: Learn how to have conversations with AI models, work with different providers, and handle multi-modal inputs
redirect_from:
  - /guides/chat
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

* How to start and continue conversations with AI models
* How to select and work with different models and providers
* How to guide AI behavior with system prompts
* How to work with images, audio, documents, and other file types
* How to control response creativity and format
* How to get structured output with JSON schemas
* How to track token usage and costs
* How to handle streaming responses and events

## Starting a Conversation

When you want to interact with an AI model, you create a chat instance. The simplest approach uses `RubyLLM.chat`, which creates a new conversation with your configured default model.

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

The `ask` method adds your message to the conversation history with the `:user` role, sends the entire conversation history to the AI provider, and returns a `RubyLLM::Message` object containing the assistant's response.

The `say` method is an alias for `ask`, so you can use whichever feels more natural in your code.

## Continuing the Conversation

One of the key features of chat-based AI models is their ability to maintain context across multiple exchanges. The `Chat` object automatically manages this conversation history for you.

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

Each time you call `ask`, RubyLLM sends the entire conversation history to the AI provider. This allows the model to understand the full context of your conversation, enabling natural follow-up questions and maintaining coherent dialogue.

## Guiding AI Behavior with System Prompts

System prompts, also called instructions, allow you to set the overall behavior, personality, and constraints for the AI assistant. These instructions persist throughout the conversation and help ensure consistent responses.

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

System prompts are added to the conversation as messages with the `:system` role and are sent with every request to the AI provider. This ensures the model always considers your instructions when generating responses.

> When using the [Rails Integration]({% link _advanced/rails.md %}), system messages are persisted in your database along with user and assistant messages, maintaining the full conversation context.
{: .note }

## Working with Different Models

RubyLLM supports over 600 models from various providers. While `RubyLLM.chat` uses your configured default model, you can specify different models:

```ruby
# Use a specific model via ID or alias
chat_claude = RubyLLM.chat(model: '{{ site.models.anthropic_current }}')
chat_gemini = RubyLLM.chat(model: '{{ site.models.gemini_current_latest }}')

# Change the model on an existing chat instance
chat = RubyLLM.chat(model: '{{ site.models.default_chat }}')
response1 = chat.ask "Initial question..."

chat.with_model('{{ site.models.anthropic_latest }}')
response2 = chat.ask "Follow-up question..."
```

For detailed information about model selection, capabilities, aliases, and working with custom models, see the [Working with Models Guide]({% link _advanced/models.md %}).

## Multi-modal Conversations

Many modern AI models can process multiple types of input beyond just text. RubyLLM provides a unified interface for working with images, audio, documents, and other file types through the `with:` parameter.

### Working with Images

Vision-capable models can analyze images, answer questions about visual content, and even compare multiple images.

```ruby
# Ensure you select a vision-capable model
chat = RubyLLM.chat(model: '{{ site.models.openai_vision }}')

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

### Working with Videos

You can also analyze video files or URLs with video-capable models. RubyLLM will automatically detect video files and handle them appropriately.

```ruby
# Ask about a local video file
chat = RubyLLM.chat(model: 'gemini-2.5-flash')
response = chat.ask "What happens in this video?", with: "path/to/demo.mp4"
puts response.content

# Ask about a video from a URL
response = chat.ask "Summarize the main events in this video.", with: "https://example.com/demo_video.mp4"
puts response.content

# Combine videos with other file types
response = chat.ask "Analyze these files for visual content.", with: ["diagram.png", "demo.mp4", "notes.txt"]
puts response.content
```

> Supported video formats include .mp4, .mov, .avi, .webm, and others (provider-dependent).
>
> Only Google Gemini and VertexAI models currently support video input.
>
> Large video files may be subject to size or duration limits imposed by the provider.
{: .note }

RubyLLM automatically handles image encoding and formatting for each provider's API. Local images are read and encoded as needed, while URLs are passed directly when supported by the provider.

### Working with Audio

Audio-capable models can transcribe speech, analyze audio content, and answer questions about what they hear. Currently, models like `{{ site.models.openai_audio }}` support audio input.

```ruby
chat = RubyLLM.chat(model: '{{ site.models.openai_audio }}') # Use an audio-capable model

# Transcribe or ask questions about audio content
response = chat.ask "Please transcribe this meeting recording.", with: "path/to/meeting.mp3"
puts response.content

# Ask follow-up questions based on the audio context
response = chat.ask "What were the main action items discussed?"
puts response.content
```

### Working with Text Files

You can provide text files directly to models for analysis, summarization, or question answering. This works with any text-based format including plain text, code files, CSV, JSON, and more.

```ruby
chat = RubyLLM.chat(model: '{{ site.models.anthropic_current }}')

# Analyze a text file
response = chat.ask "Summarize the key points in this document.", with: "path/to/document.txt"
puts response.content

# Ask questions about code files
response = chat.ask "Explain what this Ruby file does.", with: "app/models/user.rb"
puts response.content
```

### Working with PDFs

PDF support allows models to analyze complex documents including reports, manuals, and research papers. Currently, Claude 3+ and Gemini models offer the best PDF support.

```ruby
# Use a model that supports PDFs
chat = RubyLLM.chat(model: '{{ site.models.anthropic_newest }}')

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

> Be mindful of provider-specific limits. For example, Anthropic Claude models currently have a 10MB per-file size limit, and the total size/token count of all PDFs must fit within the model's context window (e.g., 200,000 tokens for Claude 3 models).
{: .note }

### Automatic File Type Detection

RubyLLM automatically detects file types based on extensions and content, so you can pass files directly without specifying the type:

```ruby
chat = RubyLLM.chat(model: '{{ site.models.anthropic_current }}')

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
- **Videos:** .mp4, .mov, .avi, .webm
- **Audio:** .mp3, .wav, .m4a, .ogg, .flac
- **Documents:** .pdf, .txt, .md, .csv, .json, .xml
- **Code:** .rb, .py, .js, .html, .css (and many others)

## Controlling Response Behavior

### Temperature and Creativity

The temperature parameter controls the randomness of the model's responses. Understanding temperature helps you get the right balance between creativity and consistency for your use case.

* **Low temperature (0.0 - 0.3)**: More deterministic and focused responses. Use for factual queries, technical explanations, or when consistency is important.
* **Medium temperature (0.4 - 0.7)**: Balanced creativity and coherence. Good for general conversation and most applications.
* **High temperature (0.8 - 1.0)**: More creative and varied responses. Use for brainstorming, creative writing, or when you want diverse outputs.

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

The `with_temperature` method returns the chat instance, allowing you to chain multiple configuration calls together.

### Provider-Specific Parameters

Different providers offer unique features and parameters. The `with_params` method lets you access these provider-specific capabilities while maintaining RubyLLM's unified interface. Parameters passed via `with_params` will override any defaults set by RubyLLM, giving you full control over the API request payload.

```ruby
# response_format parameter is supported by :openai, :ollama, :deepseek
chat = RubyLLM.chat.with_params(response_format: { type: 'json_object' })
response = chat.ask "What is the square root of 64? Answer with a JSON object with the key `result`."
puts JSON.parse(response.content)
```

> **With great power comes great responsibility:** The `with_params` method can override any part of the request payload, including critical parameters like model, max_tokens, or tools. Use it carefully to avoid unintended behavior. Always verify that your overrides are compatible with the provider's API. To debug and see the exact request being sent, set the environment variable `RUBYLLM_DEBUG=true`.
{: .warning }

> Available parameters vary by provider and model. Always consult the provider's documentation for supported features. RubyLLM passes these parameters through without validation, so incorrect parameters may cause API errors. Parameters from `with_params` take precedence over RubyLLM's defaults, allowing you to override any aspect of the request payload.
{: .warning }

### Custom HTTP Headers

Some providers offer beta features or special capabilities through custom HTTP headers. The `with_headers` method lets you add these headers to your API requests while maintaining RubyLLM's security model.

```ruby
# Enable Anthropic's beta features
chat = RubyLLM.chat(model: '{{ site.models.anthropic_current }}')
      .with_headers('anthropic-beta' => 'fine-grained-tool-streaming-2025-05-14')

response = chat.ask "Tell me about the weather"
```

Headers are merged with provider defaults, with provider headers taking precedence for security. This means you can't override authentication or critical headers, but you can add supplementary headers for optional features.

```ruby
# Chain with other configuration methods
chat = RubyLLM.chat
      .with_temperature(0.5)
      .with_headers('X-Custom-Feature' => 'enabled')
      .with_params(max_tokens: 1000)
```

> Use custom headers with caution. They may enable experimental features that could change or be removed without notice. Always refer to your provider's documentation for supported headers and their behavior.
{: .warning }

## Getting Structured Output

When building applications, you often need AI responses in a specific format for parsing and processing. RubyLLM provides two approaches: JSON mode for valid JSON output, and structured output for guaranteed schema compliance.

> JSON mode (using `with_params(response_format: { type: 'json_object' })`) guarantees valid JSON but not any specific structure. Structured output (`with_schema`) guarantees the response matches your exact schema with required fields and types. Use structured output when you need predictable, validated responses.
{: .note }

```ruby
# JSON mode - guarantees valid JSON, but no specific structure
chat = RubyLLM.chat.with_params(response_format: { type: 'json_object' })
response = chat.ask("List 3 programming languages with their year created. Return as JSON.")
# Could return any valid JSON structure

# Structured output - guarantees exact schema
class LanguagesSchema < RubyLLM::Schema
  array :languages do
    object do
      string :name
      integer :year
    end
  end
end

chat = RubyLLM.chat.with_schema(LanguagesSchema)
response = chat.ask("List 3 programming languages with their year created")
# Always returns: {"languages" => [{"name" => "...", "year" => ...}, ...]}
```

### Using RubyLLM::Schema (Recommended)

The easiest way to define schemas is with the [RubyLLM::Schema](https://github.com/danielfriis/ruby_llm-schema) gem:

```ruby
# First, add to your Gemfile:
# gem 'ruby_llm-schema'
#
# Then in your code:
require 'ruby_llm/schema'

# Define your schema as a class
class PersonSchema < RubyLLM::Schema
  string :name, description: "Person's full name"
  integer :age, description: "Person's age in years"
  string :city, required: false, description: "City where they live"
end

# Use it with a chat
chat = RubyLLM.chat
response = chat.with_schema(PersonSchema).ask("Generate a person named Alice who is 30 years old")

# The response is automatically parsed from JSON
puts response.content # => {"name" => "Alice", "age" => 30}
puts response.content.class # => Hash
```

### Using Manual JSON Schemas

If you prefer not to use RubyLLM::Schema, you can provide a JSON Schema directly:

```ruby
person_schema = {
  type: 'object',
  properties: {
    name: { type: 'string' },
    age: { type: 'integer' },
    hobbies: {
      type: 'array',
      items: { type: 'string' }
    }
  },
  required: ['name', 'age', 'hobbies'],
  additionalProperties: false  # Required for OpenAI structured output
}

chat = RubyLLM.chat
response = chat.with_schema(person_schema).ask("Generate a person who likes Ruby")

# Response is automatically parsed
puts response.content
# => {"name" => "Bob", "age" => 25, "hobbies" => ["Ruby programming", "Open source"]}
```

> **OpenAI Requirement:** When using manual JSON schemas with OpenAI, you must include `additionalProperties: false` in your schema objects. RubyLLM::Schema handles this automatically.
{: .warning }

### Complex Nested Schemas

Structured output supports complex nested objects and arrays:

```ruby
class CompanySchema < RubyLLM::Schema
  string :name, description: "Company name"

  array :employees do
    object do
      string :name
      string :role, enum: ["developer", "designer", "manager"]
      array :skills, of: :string
    end
  end

  object :metadata do
    integer :founded
    string :industry
  end
end

chat = RubyLLM.chat
response = chat.with_schema(CompanySchema).ask("Generate a small tech startup")

# Access nested data
response.content["employees"].each do |employee|
  puts "#{employee['name']} - #{employee['role']}"
end
```

### Provider Support

Not all models support structured output. Currently supported:
- **OpenAI**: GPT-4o, GPT-4o-mini, and newer models
- **Anthropic**: No native structured output support. You can simulate it with tool definitions or careful prompting
- **Gemini**: Gemini 1.5 Pro/Flash and newer

Models that don't support structured output:

```ruby
chat = RubyLLM.chat(model: '{{ site.models.openai_legacy }}')
chat.with_schema(schema)
response = chat.ask('Generate a person')
# Provider will return an error if unsupported
```

### Multi-turn Conversations with Schemas

You can add or remove schemas during a conversation:

```ruby
# Start with a schema
chat = RubyLLM.chat
chat.with_schema(PersonSchema)
person = chat.ask("Generate a person")

# Remove the schema for free-form responses
chat.with_schema(nil)
analysis = chat.ask("Tell me about this person's potential career paths")

# Add a different schema
class CareerPlanSchema < RubyLLM::Schema
  string :title
  array :steps, of: :string
  integer :years_required
end

chat.with_schema(CareerPlanSchema)
career = chat.ask("Now structure a career plan")

puts person.content
puts analysis.content
puts career.content
```

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

Refer to the [Working with Models Guide]({% link _advanced/models.md %}) for details on accessing model-specific pricing.

## Chat Event Handlers

You can register blocks to be called when certain events occur during the chat lifecycle. This is particularly useful for UI updates, logging, analytics, or building real-time chat interfaces.

### Available Event Handlers

RubyLLM provides four event handlers that cover the complete chat lifecycle:

```ruby
chat = RubyLLM.chat

# Called at first chunk received from the assistant
chat.on_new_message do
  print "Assistant > "
end

# Called after the complete assistant message (including tool calls/results) is received
chat.on_end_message do |message|
  puts "Response complete!"
  # Note: message might be nil if an error occurred during the request
  if message && message.output_tokens
    puts "Used #{message.input_tokens + message.output_tokens} tokens"
  end
end

# Called when the AI decides to use a tool
chat.on_tool_call do |tool_call|
  puts "AI is calling tool: #{tool_call.name} with arguments: #{tool_call.arguments}"
end

# Called after a tool returns its result
chat.on_tool_result do |result|
  puts "Tool returned: #{result}"
end

# These callbacks work for both streaming and non-streaming requests
chat.ask "What is metaprogramming in Ruby?"
```

## Raw Responses

You can access the raw response from the API provider with `response.raw`.

```ruby
response = chat.ask("What is the capital of France?")
puts response.raw.body
```

The raw response is a `Faraday::Response` object, which you can use to access the headers, body, and status code.

## Next Steps

This guide covered the core `Chat` interface. Now you might want to explore:

*   [Working with Models]({% link _advanced/models.md %}): Learn how to choose the best model and handle custom endpoints.
*   [Using Tools]({% link _core_features/tools.md %}): Enable the AI to call your Ruby code.
*   [Streaming Responses]({% link _core_features/streaming.md %}): Get real-time feedback from the AI.
*   [Rails Integration]({% link _advanced/rails.md %}): Persist your chat conversations easily.
*   [Error Handling]({% link _advanced/error-handling.md %}): Build robust applications that handle API issues.

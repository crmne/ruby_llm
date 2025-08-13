<picture>
  <source media="(prefers-color-scheme: dark)" srcset="/docs/assets/images/logotype_dark.svg">
  <img src="/docs/assets/images/logotype.svg" alt="RubyLLM" height="120" width="250">
</picture>

**One *beautiful* Ruby API for GPT, Claude, Gemini, and more.** Easily build chatbots, AI agents, RAG applications, and content generators. Features chat (text, images, audio, PDFs), image generation, embeddings, tools (function calling), structured output, Rails integration, and streaming. Works with OpenAI, Anthropic, Google Gemini, AWS Bedrock, DeepSeek, Mistral, Ollama (local models), OpenRouter, Perplexity, GPUStack, and any OpenAI-compatible API.

<div class="badge-container">
  <a href="https://badge.fury.io/rb/ruby_llm"><img src="https://badge.fury.io/rb/ruby_llm.svg?a=4" alt="Gem Version" /></a>
  <a href="https://github.com/testdouble/standard"><img src="https://img.shields.io/badge/code_style-standard-brightgreen.svg" alt="Ruby Style Guide" /></a>
  <a href="https://rubygems.org/gems/ruby_llm"><img alt="Gem Downloads" src="https://img.shields.io/gem/dt/ruby_llm"></a>
  <a href="https://codecov.io/gh/crmne/ruby_llm"><img src="https://codecov.io/gh/crmne/ruby_llm/branch/main/graph/badge.svg" alt="codecov" /></a>
</div>

Battle tested at [<picture><source media="(prefers-color-scheme: dark)" srcset="https://chatwithwork.com/logotype-dark.svg"><img src="https://chatwithwork.com/logotype.svg" alt="Chat with Work" height="30" align="absmiddle"></picture>](https://chatwithwork.com) — *Claude Code for your documents*

## The problem with AI libraries

Every AI provider comes with its own client library, its own response format, its own conventions for streaming, and its own way of handling errors. Want to use multiple providers? Prepare to juggle incompatible APIs and bloated dependencies.

RubyLLM fixes all that. One beautiful API for everything. One consistent format. Minimal dependencies — just Faraday, Zeitwerk, and Marcel. Because working with AI should be a joy, not a chore.

## What makes it great

```ruby
# Just ask questions
chat = RubyLLM.chat
chat.ask "What's the best way to learn Ruby?"

# Analyze images, audio, documents, and text files
chat.ask "What's in this image?", with: "ruby_conf.jpg"
chat.ask "Describe this meeting", with: "meeting.wav"
chat.ask "Summarize this document", with: "contract.pdf"
chat.ask "Explain this code", with: "app.rb"

# Multiple files at once - types automatically detected
chat.ask "Analyze these files", with: ["diagram.png", "report.pdf", "notes.txt"]

# Stream responses in real-time
chat.ask "Tell me a story about a Ruby programmer" do |chunk|
  print chunk.content
end

# Generate images
RubyLLM.paint "a sunset over mountains in watercolor style"

# Create vector embeddings
RubyLLM.embed "Ruby is elegant and expressive"

# Let AI use your code
class Weather < RubyLLM::Tool
  description "Gets current weather for a location"
  param :latitude, desc: "Latitude (e.g., 52.5200)"
  param :longitude, desc: "Longitude (e.g., 13.4050)"

  def execute(latitude:, longitude:)
    url = "https://api.open-meteo.com/v1/forecast?latitude=#{latitude}&longitude=#{longitude}&current=temperature_2m,wind_speed_10m"

    response = Faraday.get(url)
    data = JSON.parse(response.body)
  rescue => e
    { error: e.message }
  end
end

chat.with_tool(Weather).ask "What's the weather in Berlin? (52.5200, 13.4050)"

# Get structured output with JSON schemas
class ProductSchema < RubyLLM::Schema
  string :name, description: "Product name"
  number :price, description: "Price in USD"
  array :features, description: "Key features" do
    string description: "Feature description"
  end
end

response = chat.with_schema(ProductSchema)
               .ask "Analyze this product description", with: "product.txt"
# response.content => { "name" => "...", "price" => 99.99, "features" => [...] }
```

## Core Capabilities

*   💬 **Unified Chat:** Converse with models from OpenAI, Anthropic, Gemini, Bedrock, OpenRouter, DeepSeek, Perplexity, Mistral, Ollama, or any OpenAI-compatible API using `RubyLLM.chat`.
*   👁️ **Vision:** Analyze images within chats.
*   🔊 **Audio:** Transcribe and understand audio content.
*   📄 **Document Analysis:** Extract information from PDFs, text files, CSV, JSON, XML, Markdown, and code files.
*   🖼️ **Image Generation:** Create images with `RubyLLM.paint`.
*   📊 **Embeddings:** Generate text embeddings for vector search with `RubyLLM.embed`.
*   🔧 **Tools (Function Calling):** Let AI models call your Ruby code using `RubyLLM::Tool`.
*   📋 **Structured Output:** Guarantee responses conform to JSON schemas with `RubyLLM::Schema`.
*   🚂 **Rails Integration:** Easily persist chats, messages, and tool calls using `acts_as_chat` and `acts_as_message`.
*   🌊 **Streaming:** Process responses in real-time with idiomatic Ruby blocks.
*   ⚡ **Async Support:** Built-in fiber-based concurrency for high-performance operations.
*   🎯 **Smart Configuration:** Global and scoped configs with automatic retries and proxy support.
*   📚 **Model Registry:** Access 500+ models with capability detection and pricing info.

## Installation

Add to your Gemfile:
```ruby
gem 'ruby_llm'
```
Then `bundle install`.

Configure your API keys (using environment variables is recommended):
```ruby
# config/initializers/ruby_llm.rb or similar
RubyLLM.configure do |config|
  config.openai_api_key = ENV.fetch('OPENAI_API_KEY', nil)
  # Add keys ONLY for providers you intend to use
  # config.anthropic_api_key = ENV.fetch('ANTHROPIC_API_KEY', nil)
  # ... see Configuration guide for all options ...
end
```
See the [Installation Guide](https://rubyllm.com/installation) for full details.

## Rails Integration

Add persistence to your chat models effortlessly:

```bash
# Generate models and migrations
rails generate ruby_llm:install
```

```ruby
# Or add to existing models
class Chat < ApplicationRecord
  acts_as_chat # Automatically saves messages & tool calls
end

class Message < ApplicationRecord
  acts_as_message
end

class ToolCall < ApplicationRecord
  acts_as_tool_call
end

# Now chats persist automatically
chat = Chat.create!(model_id: "gpt-4.1-nano")
chat.ask("What's in this file?", with: "report.pdf")
```

See the [Rails Integration Guide](https://rubyllm.com/guides/rails) for details.

## Learn More

Dive deeper with the official documentation:

-   [Installation](https://rubyllm.com/installation)
-   [Configuration](https://rubyllm.com/configuration)
-   **Guides:**
    -   [Getting Started](https://rubyllm.com/guides/getting-started)
    -   [Chatting with AI Models](https://rubyllm.com/guides/chat)
    -   [Using Tools](https://rubyllm.com/guides/tools)
    -   [Streaming Responses](https://rubyllm.com/guides/streaming)
    -   [Rails Integration](https://rubyllm.com/guides/rails)
    -   [Image Generation](https://rubyllm.com/guides/image-generation)
    -   [Embeddings](https://rubyllm.com/guides/embeddings)
    -   [Working with Models](https://rubyllm.com/guides/models)
    -   [Error Handling](https://rubyllm.com/guides/error-handling)
    -   [Available Models](https://rubyllm.com/guides/available-models)

## Contributing

We welcome contributions! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for details on setup, testing, and contribution guidelines.

## License

Released under the MIT License.

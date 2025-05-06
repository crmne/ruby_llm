---
layout: default
title: Home
nav_order: 1
description: "RubyLLM is a delightful Ruby way to work with AI."
permalink: /
---

<div class="logo-container">
  <img src="/assets/images/logotype.svg" alt="RubyLLM" height="120" width="250">
  <iframe src="https://ghbtns.com/github-btn.html?user=crmne&repo=ruby_llm&type=star&count=true&size=large" frameborder="0" scrolling="0" width="170" height="30" title="GitHub" style="vertical-align: middle; display: inline-block;"></iframe>
</div>

A delightful Ruby way to work with AI through a unified interface to Anthropic, AWS Bedrock Anthropic, DeepSeek, Ollama, OpenAI, Gemini, OpenRouter, and any OpenAI-compatible API.
{: .fs-6 .fw-300 }

<a href="{% link installation.md %}" class="btn btn-primary fs-5 mb-4 mb-md-0 mr-2" style="margin: 0;">Get started</a>
<a href="https://github.com/crmne/ruby_llm" class="btn fs-5 mb-4 mb-md-0 mr-2" style="margin: 0;">GitHub</a>

---

<div class="provider-icons">
  <div class="provider-logo">
    <img src="https://registry.npmmirror.com/@lobehub/icons-static-svg/latest/files/icons/anthropic-text.svg" alt="Anthropic" class="logo-small">
  </div>
  <div class="provider-logo">
    <img src="https://registry.npmmirror.com/@lobehub/icons-static-svg/latest/files/icons/bedrock-color.svg" alt="Bedrock" class="logo-medium">
    <img src="https://registry.npmmirror.com/@lobehub/icons-static-svg/latest/files/icons/bedrock-text.svg" alt="Bedrock" class="logo-small">
  </div>
  <div class="provider-logo">
    <img src="https://registry.npmmirror.com/@lobehub/icons-static-svg/latest/files/icons/deepseek-color.svg" alt="DeepSeek" class="logo-medium">
    <img src="https://registry.npmmirror.com/@lobehub/icons-static-svg/latest/files/icons/deepseek-text.svg" alt="DeepSeek" class="logo-small">
  </div>
  <div class="provider-logo">
    <img src="https://registry.npmmirror.com/@lobehub/icons-static-svg/latest/files/icons/gemini-brand-color.svg" alt="Gemini" class="logo-large">
  </div>
  <div class="provider-logo">
    <img src="https://registry.npmmirror.com/@lobehub/icons-static-svg/latest/files/icons/ollama.svg" alt="Ollama" class="logo-medium">
    <img src="https://registry.npmmirror.com/@lobehub/icons-static-svg/latest/files/icons/ollama-text.svg" alt="Ollama" class="logo-medium">
  </div>
  <div class="provider-logo">
    <img src="https://registry.npmmirror.com/@lobehub/icons-static-svg/latest/files/icons/openai.svg" alt="OpenAI" class="logo-medium">
    <img src="https://registry.npmmirror.com/@lobehub/icons-static-svg/latest/files/icons/openai-text.svg" alt="OpenAI" class="logo-medium">
  </div>
  <div class="provider-logo">
    <img src="https://registry.npmmirror.com/@lobehub/icons-static-svg/latest/files/icons/openrouter.svg" alt="OpenRouter" class="logo-medium">
    <img src="https://registry.npmmirror.com/@lobehub/icons-static-svg/latest/files/icons/openrouter-text.svg" alt="OpenRouter" class="logo-small">
  </div>
</div>

<div class="badge-container">
  <a href="https://badge.fury.io/rb/ruby_llm"><img src="https://badge.fury.io/rb/ruby_llm.svg" alt="Gem Version" /></a>
  <a href="https://github.com/testdouble/standard"><img src="https://img.shields.io/badge/code_style-standard-brightgreen.svg" alt="Ruby Style Guide" /></a>
  <a href="https://rubygems.org/gems/ruby_llm"><img alt="Gem Downloads" src="https://img.shields.io/gem/dt/ruby_llm"></a>
  <a href="https://codecov.io/gh/crmne/ruby_llm"><img src="https://codecov.io/gh/crmne/ruby_llm/branch/main/graph/badge.svg" alt="codecov" /></a>
</div>

🤺 Battle tested at [💬  Chat with Work](https://chatwithwork.com)

---

## The problem with AI libraries

Every AI provider comes with its own client library, its own response format, its own conventions for streaming, and its own way of handling errors. Want to use multiple providers? Prepare to juggle incompatible APIs and bloated dependencies.

RubyLLM fixes all that. One beautiful API for everything. One consistent format. Minimal dependencies — just Faraday and Zeitwerk. Because working with AI should be a joy, not a chore.

## What makes it great

```ruby
# Just ask questions
chat = RubyLLM.chat
chat.ask "What's the best way to learn Ruby?"

# Analyze images
chat.ask "What's in this image?", with: { image: "ruby_conf.jpg" }

# Analyze audio recordings
chat.ask "Describe this meeting", with: { audio: "meeting.wav" }

# Analyze documents
chat.ask "Summarize this document", with: { pdf: "contract.pdf" }

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
```

## Core Capabilities

*   💬 **Unified Chat:** Converse with models from OpenAI, Anthropic, Gemini, Bedrock, OpenRouter, DeepSeek, Ollama, or any OpenAI-compatible API using `RubyLLM.chat`.
*   👁️ **Vision:** Analyze images within chats.
*   🔊 **Audio:** Transcribe and understand audio content.
*   📄 **PDF Analysis:** Extract information and summarize PDF documents.
*   🖼️ **Image Generation:** Create images with `RubyLLM.paint`.
*   📊 **Embeddings:** Generate text embeddings for vector search with `RubyLLM.embed`.
*   🔧 **Tools (Function Calling):** Let AI models call your Ruby code using `RubyLLM::Tool`.
*   🚂 **Rails Integration:** Easily persist chats, messages, and tool calls using `acts_as_chat` and `acts_as_message`.
*   🌊 **Streaming:** Process responses in real-time with idiomatic Ruby blocks.

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

```ruby
# app/models/chat.rb
class Chat < ApplicationRecord
  acts_as_chat # Automatically saves messages & tool calls
  # ... your other model logic ...
end

# app/models/message.rb
class Message < ApplicationRecord
  acts_as_message
  # ...
end

# app/models/tool_call.rb (if using tools)
class ToolCall < ApplicationRecord
  acts_as_tool_call
  # ...
end

# Now interacting with a Chat record persists the conversation:
chat_record = Chat.create!(model_id: "gpt-4.1-nano")
chat_record.ask("Explain Active Record callbacks.") # User & Assistant messages saved
```
Check the [Rails Integration Guide](https://rubyllm.com/guides/rails) for more.

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
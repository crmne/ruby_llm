---
layout: default
title: Home
nav_order: 1
description: One beautiful Ruby API for GPT, Claude, Gemini, and more. Easily build chatbots, AI agents, RAG applications, and content generators.
permalink: /
---

<h1>
  <div class="logo-container">
    <img src="/assets/images/logotype.svg" alt="RubyLLM" height="120" width="250">
    <div style="transform: scale(1.2); transform-origin: left center; display: inline-block; margin-left: 20px;">
      <a class="github-button" href="https://github.com/crmne/ruby_llm" data-color-scheme="no-preference: light; light: light; dark: dark;" data-icon="octicon-star" data-size="large" data-show-count="true" aria-label="Star crmne/ruby_llm on GitHub">Star</a>
    </div>
  </div>
</h1>

<script async defer src="https://buttons.github.io/buttons.js"></script>

{{ page.description }}
{: .fs-6 .fw-300 }

<a href="{% link _getting_started/getting-started.md %}" class="btn btn-primary fs-5 mb-4 mb-md-0 mr-2" style="margin: 0;">Get started</a>
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
    <img src="https://raw.githubusercontent.com/gpustack/gpustack/main/docs/assets/gpustack-logo.png" alt="GPUStack" class="logo-medium">
  </div>
  <div class="provider-logo">
    <img src="https://registry.npmmirror.com/@lobehub/icons-static-svg/latest/files/icons/mistral-color.svg" alt="Mistral" class="logo-medium">
    <img src="https://registry.npmmirror.com/@lobehub/icons-static-svg/latest/files/icons/mistral-text.svg" alt="Mistral" class="logo-small">
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
  <div class="provider-logo">
    <img src="https://registry.npmmirror.com/@lobehub/icons-static-svg/latest/files/icons/perplexity-color.svg" alt="Perplexity" class="logo-medium">
    <img src="https://registry.npmmirror.com/@lobehub/icons-static-svg/latest/files/icons/perplexity-text.svg" alt="Perplexity" class="logo-small">
  </div>
  <div class="provider-logo">
    <img src="https://registry.npmmirror.com/@lobehub/icons-static-svg/latest/files/icons/vertexai-color.svg" alt="VertexAI" class="logo-medium">
    <img src="https://registry.npmmirror.com/@lobehub/icons-static-svg/latest/files/icons/vertexai-text.svg" alt="VertexAI" class="logo-small">
  </div>
</div>

<div class="badge-container">
  <a href="https://badge.fury.io/rb/ruby_llm"><img src="https://badge.fury.io/rb/ruby_llm.svg" alt="Gem Version" /></a>
  <a href="https://github.com/rubocop/rubocop"><img src="https://img.shields.io/badge/code_style-rubocop-brightgreen.svg" alt="Ruby Style Guide" /></a>
  <a href="https://rubygems.org/gems/ruby_llm"><img alt="Gem Downloads" src="https://img.shields.io/gem/dt/ruby_llm"></a>
  <a href="https://codecov.io/gh/crmne/ruby_llm"><img src="https://codecov.io/gh/crmne/ruby_llm/branch/main/graph/badge.svg" alt="codecov" /></a>
</div>

<a href="https://trendshift.io/repositories/13640" target="_blank"><img src="https://trendshift.io/api/badge/repositories/13640" alt="crmne%2Fruby_llm | Trendshift" style="width: 250px; height: 55px;" width="250" height="55"/></a>

Battle tested at [<img src="https://chatwithwork.com/logotype.svg" alt="Chat with Work" class="chatwithwork-logo" style="height: 2em; vertical-align: middle;">](https://chatwithwork.com) — *Claude Code for your documents*

Using RubyLLM in production? [Share your story](https://tally.so/r/3Na02p)! Takes 5 minutes.
{: .note }

---

## Why RubyLLM?

Every AI provider ships their own bloated client. Different APIs. Different response formats. Different conventions. It's exhausting.

RubyLLM gives you one beautiful API for all of them. Same interface whether you're using GPT, Claude, or your local Ollama. Just three dependencies: Faraday, Zeitwerk, and Marcel. That's it.

## Show me the code

```ruby
# Just ask questions
chat = RubyLLM.chat
chat.ask "What's the best way to learn Ruby?"
```

```ruby
# Analyze any file type
chat.ask "What's in this image?", with: "ruby_conf.jpg"
chat.ask "What's happening in this video?", with: "video.mp4"
chat.ask "Describe this meeting", with: "meeting.wav"
chat.ask "Summarize this document", with: "contract.pdf"
chat.ask "Explain this code", with: "app.rb"
```

```ruby
# Multiple files at once
chat.ask "Analyze these files", with: ["diagram.png", "report.pdf", "notes.txt"]
```

```ruby
# Stream responses
chat.ask "Tell me a story about Ruby" do |chunk|
  print chunk.content
end
```

```ruby
# Generate images
RubyLLM.paint "a sunset over mountains in watercolor style"
```

```ruby
# Create embeddings
RubyLLM.embed "Ruby is elegant and expressive"
```

```ruby
# Moderate content for safety
RubyLLM.moderate "Check if this text is safe"
```

```ruby
# Let AI use your code
class Weather < RubyLLM::Tool
  description "Get current weather"
  param :latitude
  param :longitude

  def execute(latitude:, longitude:)
    url = "https://api.open-meteo.com/v1/forecast?latitude=#{latitude}&longitude=#{longitude}&current=temperature_2m,wind_speed_10m"
    JSON.parse(Faraday.get(url).body)
  end
end

chat.with_tool(Weather).ask "What's the weather in Berlin?"
```

```ruby
# Get structured output
class ProductSchema < RubyLLM::Schema
  string :name
  number :price
  array :features do
    string
  end
end

response = chat.with_schema(ProductSchema).ask "Analyze this product", with: "product.txt"
```

## Features

* **Chat:** Conversational AI with `RubyLLM.chat`
* **Vision:** Analyze images and screenshots
* **Audio:** Transcribe and understand speech
* **Documents:** Extract from PDFs, CSVs, JSON, any file type
* **Image generation:** Create images with `RubyLLM.paint`
* **Embeddings:** Vector search with `RubyLLM.embed`
* **Moderation:** Content safety with `RubyLLM.moderate`
* **Tools:** Let AI call your Ruby methods
* **Structured output:** JSON schemas that just work
* **Streaming:** Real-time responses with blocks
* **Rails:** ActiveRecord integration with `acts_as_chat`
* **Async:** Fiber-based concurrency
* **Model registry:** 500+ models with capability detection and pricing
* **Providers:** OpenAI, Anthropic, Gemini, VertexAI, Bedrock, DeepSeek, Mistral, Ollama, OpenRouter, Perplexity, GPUStack, and any OpenAI-compatible API

## Installation

Add to your Gemfile:
```ruby
gem 'ruby_llm'
```
Then `bundle install`.

Configure your API keys:
```ruby
# config/initializers/ruby_llm.rb
RubyLLM.configure do |config|
  config.openai_api_key = ENV['OPENAI_API_KEY']
end
```

## Rails

```bash
# Install Rails Integration
rails generate ruby_llm:install

# Add Chat UI (optional)
rails generate ruby_llm:chat_ui
```

```ruby
class Chat < ApplicationRecord
  acts_as_chat
end

chat = Chat.create! model: "claude-sonnet-4"
chat.ask "What's in this file?", with: "report.pdf"
```

Visit `http://localhost:3000/chats` for a ready-to-use chat interface!


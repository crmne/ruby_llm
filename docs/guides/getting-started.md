---
layout: default
title: Getting Started
parent: Guides
nav_order: 1
permalink: /guides/getting-started
---

# Getting Started with RubyLLM

This guide will help you get up and running with RubyLLM, showing you the basics of chatting with AI models, generating images, and creating embeddings.

## Prerequisites

Before starting, make sure you have:

1. Installed the RubyLLM gem (see the [Installation guide]({% link installation.md %}))
2. At least one API key from a supported provider (OpenAI, Anthropic, Google, AWS Bedrock, or DeepSeek)

## Basic Configuration

Let's start by setting up RubyLLM with your API keys:

```ruby
require 'ruby_llm'

RubyLLM.configure do |config|
  # Add the API keys you have available
  config.openai_api_key = ENV.fetch('OPENAI_API_KEY', nil)
  config.anthropic_api_key = ENV.fetch('ANTHROPIC_API_KEY', nil)
  config.gemini_api_key = ENV.fetch('GEMINI_API_KEY', nil)
  config.deepseek_api_key = ENV.fetch('DEEPSEEK_API_KEY', nil)

  # Bedrock
  config.bedrock_api_key = ENV.fetch('AWS_ACCESS_KEY_ID', nil)
  config.bedrock_secret_key = ENV.fetch('AWS_SECRET_ACCESS_KEY', nil)
  config.bedrock_region = ENV.fetch('AWS_REGION', nil)
  config.bedrock_session_token = ENV.fetch('AWS_SESSION_TOKEN', nil)
end
```

## Your First Chat

Let's start with a simple chat interaction:

```ruby
# Create a chat (uses the default model)
chat = RubyLLM.chat

# Ask a question
response = chat.ask "What's the capital of France?"
puts response.content
# => "The capital of France is Paris."

# Continue the conversation
response = chat.ask "What's the population of that city?"
puts response.content
# => "Paris has a population of approximately 2.1 million people..."
```

### Using a Specific Model

You can specify which model you want to use:

```ruby
# Use Claude
claude_chat = RubyLLM.chat(model: 'claude-3-5-sonnet-20241022')
claude_chat.ask "Tell me about Ruby programming language"

# Use Gemini
gemini_chat = RubyLLM.chat(model: 'gemini-2.0-flash')
gemini_chat.ask "What are the best Ruby gems for machine learning?"
```

## Exploring Available Models

RubyLLM gives you access to models from multiple providers. You can see what's available:

```ruby
# List all models
all_models = RubyLLM.models.all
puts "Total models: #{all_models.count}"

# List chat models
chat_models = RubyLLM.models.chat_models
puts "Chat models:"
chat_models.each do |model|
  puts "- #{model.id} (#{model.provider})"
end

# List embedding models
RubyLLM.models.embedding_models.each do |model|
  puts "- #{model.id} (#{model.provider})"
end

# Find info about a specific model
gpt = RubyLLM.models.find('gpt-4o-mini')
puts "Context window: #{gpt.context_window}"
puts "Max tokens: #{gpt.max_tokens}"
puts "Pricing: $#{gpt.input_price_per_million} per million input tokens"
```

## Generating Images

RubyLLM makes it easy to generate images with DALL-E:

```ruby
# Generate an image
image = RubyLLM.paint("a sunset over mountains")

# The URL where you can view/download the image
puts image.url

# How the model interpreted your prompt
puts image.revised_prompt

# Generate a larger image
large_image = RubyLLM.paint(
  "a cyberpunk city at night with neon lights",
  size: "1792x1024"
)
```

## Creating Embeddings

Embeddings are vector representations of text that can be used for semantic search, classification, and more:

```ruby
# Create an embedding for a single text
embedding = RubyLLM.embed("Ruby is a programmer's best friend")

# The vector representation
vector = embedding.vectors
puts "Vector dimension: #{vector.length}"

# Create embeddings for multiple texts
texts = ["Ruby", "Python", "JavaScript"]
embeddings = RubyLLM.embed(texts)

# Each text gets its own vector
puts "Number of vectors: #{embeddings.vectors.length}"
```

## Working with Conversations

Here's how to have a multi-turn conversation:

```ruby
chat = RubyLLM.chat

# First message
chat.ask "What are the benefits of Ruby on Rails?"

# Follow-up questions
chat.ask "How does that compare to Django?"
chat.ask "Which one would you recommend for a new web project?"

# You can check all messages in the conversation
chat.messages.each do |message|
  puts "#{message.role}: #{message.content[0..100]}..."
end
```

## What's Next?

Now that you've got the basics down, you're ready to explore more advanced features:

- [Chatting with AI]({% link guides/chat.md %}) - Learn more about chat capabilities
- [Using Tools]({% link guides/tools.md %}) - Let AI use your Ruby code
- [Rails Integration]({% link guides/rails.md %}) - Persist chats in your Rails apps
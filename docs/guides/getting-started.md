---
layout: default
title: Getting Started
parent: Guides
nav_order: 1
permalink: /guides/getting-started
---

# Getting Started with RubyLLM
{: .no_toc }

Welcome to RubyLLM! This guide will get you up and running quickly. We'll cover installing the gem, configuring your first API key, and making basic chat, image, and embedding requests.
{: .fs-6 .fw-300 }

## Table of contents
{: .no_toc .text-delta }

1. TOC
{:toc}

---

After reading this guide, you will know:

*   How to install RubyLLM.
*   How to configure API keys.
*   How to start a simple chat conversation.
*   How to generate an image.
*   How to create text embeddings.

## Installation

Add RubyLLM to your Gemfile:

```ruby
gem 'ruby_llm'
```

Then run `bundle install`.

Alternatively, install it manually: `gem install ruby_llm`

(For full details, see the [Installation Guide]({% link installation.md %})).

## Configuration

RubyLLM needs API keys for the AI providers you want to use. Configure them, typically in an initializer (`config/initializers/ruby_llm.rb` in Rails) or at the start of your script.

```ruby
require 'ruby_llm'

RubyLLM.configure do |config|
  # Add keys for the providers you plan to use.
  # Using environment variables is recommended.
  config.openai_api_key = ENV.fetch('OPENAI_API_KEY', nil)
  # config.anthropic_api_key = ENV.fetch('ANTHROPIC_API_KEY', nil)
  # ... add other provider keys as needed
end
```

You only need to configure keys for the providers you intend to use. See the [Installation Guide]({% link installation.md %}#configuration) for all configuration options.

## Your First Chat

The primary way to interact with language models is through the `RubyLLM.chat` interface.

```ruby
# Create a chat instance (uses the default model, usually GPT)
chat = RubyLLM.chat

# Ask a question
response = chat.ask "What is Ruby on Rails?"

# The response is a RubyLLM::Message object
puts response.content
# => "Ruby on Rails, often shortened to Rails, is a server-side web application..."

# Continue the conversation naturally
response = chat.ask "What are its main advantages?"
puts response.content
# => "Some key advantages of Ruby on Rails include..."
```

RubyLLM automatically handles conversation history. Dive deeper in the [Chatting with AI Models Guide]({% link guides/chat.md %}).

## Generating an Image

You can generate images using models like DALL-E 3 via the `RubyLLM.paint` method.

```ruby
# Generate an image (uses the default image model, usually DALL-E 3)
image = RubyLLM.paint("A futuristic cityscape at sunset, watercolor style")

# Access the image URL
puts image.url
# => "https://oaidalleapiprodscus.blob.core.windows.net/..."

# See the potentially revised prompt the model used
puts image.revised_prompt
# => "A watercolor painting of a futuristic cityscape bathed in the warm hues of a setting sun..."
```

Learn more in the [Image Generation Guide]({% link guides/image-generation.md %}).

## Creating Embeddings

Embeddings represent text as numerical vectors, useful for tasks like semantic search. Use `RubyLLM.embed`.

```ruby
# Create an embedding for a single piece of text
embedding = RubyLLM.embed("Ruby is optimized for programmer happiness.")

# Access the vector (an array of floats)
vector = embedding.vectors
puts "Vector dimension: #{vector.length}" # e.g., 1536 for text-embedding-3-small

# Embed multiple texts at once
texts = ["Convention over configuration", "Model-View-Controller", "Metaprogramming"]
embeddings = RubyLLM.embed(texts)

puts "Generated #{embeddings.vectors.length} vectors." # => 3
```

Explore further in the [Embeddings Guide]({% link guides/embeddings.md %}).

## What's Next?

You've seen the basics! Now you're ready to explore RubyLLM's features in more detail:

*   [Chatting with AI Models]({% link guides/chat.md %})
*   [Working with Models]({% link guides/models.md %}) (Choosing models, custom endpoints)
*   [Using Tools]({% link guides/tools.md %}) (Letting AI call your code)
*   [Streaming Responses]({% link guides/streaming.md %})
*   [Rails Integration]({% link guides/rails.md %})
*   [Error Handling]({% link guides/error-handling.md %})
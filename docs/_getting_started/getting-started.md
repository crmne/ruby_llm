---
layout: default
title: Getting Started
nav_order: 1
description: Start building AI apps in Ruby in 5 minutes. Chat, generate images, create embeddings - all with one gem.
redirect_from:
  - /guides/getting-started
  - /installation
---

# {{ page.title }}

{{ page.description }}
{: .fs-6 .fw-300 }

After reading this guide, you will know:

*   How to install RubyLLM.
*   How to perform minimal configuration.
*   How to start a simple chat conversation.
*   How to stream a response.
*   How to generate an image and create a text embedding.
*   How to add database-backed chats to a Rails app.

## Installation

Add RubyLLM with bundler:

```sh
bundle add ruby_llm
```

## Minimal Configuration

RubyLLM needs API keys for the AI providers you want to use. Configure them once, typically when your application starts.

```ruby
# config/initializers/ruby_llm.rb (in Rails) or at the start of your script
require 'ruby_llm'

RubyLLM.configure do |config|
  config.openai_api_key = ENV.fetch('OPENAI_API_KEY', nil)
  # config.anthropic_api_key = ENV.fetch('ANTHROPIC_API_KEY', nil)
end
```

> You only need to configure keys for the providers you actually plan to use. See the [Configuration Guide]({% link _getting_started/configuration.md %}) for all options, including setting defaults and connecting to custom endpoints.
{: .note }

## Your First Chat

Interact with language models using `RubyLLM.chat`.

```ruby
chat = RubyLLM.chat

response = chat.ask "What is Ruby on Rails?"

puts response.content
# => "Ruby on Rails, often shortened to Rails, is a server-side web application..."
```

RubyLLM handles the conversation history automatically. See the [Chatting with AI Models Guide]({% link _core_features/chat.md %}) for more details.

## Streaming a Response

Pass a block to `ask` and RubyLLM yields chunks as they arrive:

```ruby
chat.ask "Tell me a story about a Ruby programmer" do |chunk|
  print chunk.content
end
```

That is all streaming takes. See the [Streaming Guide]({% link _core_features/streaming.md %}) for streaming into web pages and background jobs.

## Generating an Image

Generate images using models like GPT Image via `RubyLLM.paint`.

```ruby
image = RubyLLM.paint("A photorealistic red panda coding Ruby")

# Access the image URL (or Base64 data depending on provider)
if image.url
  puts image.url
  # => "https://..."
else
  puts "Image data received (Base64)."
end

image.save("red_panda.png")
```

Learn more in the [Image Generation Guide]({% link _core_features/image-generation.md %}).

## Creating an Embedding

Create numerical vector representations of text using `RubyLLM.embed`.

```ruby
embedding = RubyLLM.embed("Ruby is optimized for programmer happiness.")

# Access the vector (an array of floats)
vector = embedding.vectors
puts "Vector dimension: #{vector.length}" # e.g., 1536

puts "Model used: #{embedding.model}"
```

Explore further in the [Embeddings Guide]({% link _core_features/embeddings.md %}).

## Using It in Rails

Want conversations saved to your database? One generator sets up Chat and Message models with ActiveRecord persistence:

```bash
bin/rails generate ruby_llm:install
bin/rails db:migrate
```

```ruby
chat = Chat.create!(model: "{{ site.models.default_chat }}")
chat.ask "What's the best way to learn Rails?"
```

Every message persists automatically. Optionally, add a ready-to-use chat interface with Turbo streaming, controllers, and a background job:

```bash
bin/rails generate ruby_llm:chat_ui
```

Then visit `http://localhost:3000/chats` to start chatting. See the [Rails Integration Guide]({% link _advanced/rails.md %}) for full details.

## What's Next?

You've covered the basics! Now you're ready to explore RubyLLM's features in more detail:

*   [Chatting with AI Models]({% link _core_features/chat.md %})
*   [Working with Models]({% link _reference/models.md %}) (Choosing models, custom endpoints)
*   [Using Tools]({% link _core_features/tools.md %}) (Letting AI call your code)
*   [Streaming Responses]({% link _core_features/streaming.md %})
*   [Rails Integration]({% link _advanced/rails.md %})
*   [Configuration]({% link _getting_started/configuration.md %})
*   [Error Handling]({% link _advanced/error-handling.md %})

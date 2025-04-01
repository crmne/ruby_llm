---
layout: default
title: Installation
nav_order: 2
permalink: /installation
---

# Installation

RubyLLM is packaged as a Ruby gem, making it easy to install in your projects.

## Requirements

* Ruby 3.1 or later
* An API key from at least one of the supported providers:
  * OpenAI
  * Anthropic
  * Google (Gemini)
  * DeepSeek

## Installation Methods

### Using Bundler (recommended)

Add RubyLLM to your project's Gemfile:

```ruby
gem 'ruby_llm'
```

Then install the dependencies:

```bash
bundle install
```

### Manual Installation

If you're not using Bundler, you can install RubyLLM directly:

```bash
gem install ruby_llm
```

## Configuration

After installing RubyLLM, you'll need to configure it with your API keys:

```ruby
require 'ruby_llm'

RubyLLM.configure do |config|
  # Required: At least one API key
  config.openai_api_key = ENV.fetch('OPENAI_API_KEY', nil)
  config.anthropic_api_key = ENV.fetch('ANTHROPIC_API_KEY', nil)
  config.gemini_api_key = ENV.fetch('GEMINI_API_KEY', nil)
  config.deepseek_api_key = ENV.fetch('DEEPSEEK_API_KEY', nil)
  config.bedrock_api_key = ENV.fetch('AWS_ACCESS_KEY_ID', nil)
  config.bedrock_secret_key = ENV.fetch('AWS_SECRET_ACCESS_KEY', nil)
  config.bedrock_region = ENV.fetch('AWS_REGION', nil)
  config.bedrock_session_token = ENV.fetch('AWS_SESSION_TOKEN', nil)

  # Optional: Set default models
  config.default_model = 'gpt-4o-mini'               # Default chat model
  config.default_embedding_model = 'text-embedding-3-small'  # Default embedding model
  config.default_image_model = 'dall-e-3'            # Default image generation model

  # Optional: Configure request settings
  config.request_timeout = 120  # Request timeout in seconds
  config.max_retries = 3        # Number of retries on failures
end
```

We recommend storing your API keys as environment variables rather than hardcoding them in your application.

## Verifying Installation

You can verify that RubyLLM is correctly installed and configured by running a simple test:

```ruby
require 'ruby_llm'

# Configure with at least one API key
RubyLLM.configure do |config|
  config.openai_api_key = ENV['OPENAI_API_KEY']
end

# Try a simple query
chat = RubyLLM.chat
response = chat.ask "Hello, world!"
puts response.content

# Check available models
puts "Available models:"
RubyLLM.models.chat_models.each do |model|
  puts "- #{model.id} (#{model.provider})"
end
```

## Next Steps

Once you've successfully installed RubyLLM, check out the [Getting Started guide]({% link guides/getting-started.md %}) to learn how to use it in your applications.
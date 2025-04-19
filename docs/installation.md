---
layout: default
title: Installation
nav_order: 2
permalink: /installation
---

# Installation
{: .no_toc }

This guide covers how to install RubyLLM.
{: .fs-6 .fw-300 }

## Table of contents
{: .no_toc .text-delta }

1. TOC
{:toc}

---

After reading this guide, you will know:

*   RubyLLM's prerequisites.
*   How to install RubyLLM using Bundler or manually.
*   How to configure API keys and other settings.

## Prerequisites

*   Ruby 3.1 or later.
*   An API key from at least one supported provider (OpenAI, Anthropic, Google Gemini, AWS Bedrock, DeepSeek).

## Installation Methods

### Using Bundler (Recommended)

The standard way to manage gem dependencies in Ruby projects.

Add RubyLLM to your project's `Gemfile`:

```ruby
gem 'ruby_llm'
```

Then, from your terminal, install the dependencies:

```bash
bundle install
```

### Manual Installation

If you're not using Bundler (e.g., for a simple script), you can install RubyLLM directly using the `gem` command:

```bash
gem install ruby_llm
```

You'll then need to `require 'ruby_llm'` in your script.

## Configuration

RubyLLM needs API keys to communicate with AI providers. You configure these using `RubyLLM.configure`, typically once when your application starts (e.g., in `config/initializers/ruby_llm.rb` for Rails apps, or at the top of a script).

Here are all the available configuration options:

```ruby
require 'ruby_llm'

RubyLLM.configure do |config|
  # --- Provider API Keys ---
  # Provide keys ONLY for the providers you intend to use.
  # Using environment variables (ENV.fetch) is highly recommended.
  config.openai_api_key = ENV.fetch('OPENAI_API_KEY', nil)
  config.anthropic_api_key = ENV.fetch('ANTHROPIC_API_KEY', nil)
  config.gemini_api_key = ENV.fetch('GEMINI_API_KEY', nil)
  config.deepseek_api_key = ENV.fetch('DEEPSEEK_API_KEY', nil)

  # --- AWS Bedrock Credentials ---
  # Uses standard AWS credential chain (environment, shared config, IAM role)
  # if these specific keys aren't set. Region is required if using Bedrock.
  config.bedrock_api_key = ENV.fetch('AWS_ACCESS_KEY_ID', nil)
  config.bedrock_secret_key = ENV.fetch('AWS_SECRET_ACCESS_KEY', nil)
  config.bedrock_region = ENV.fetch('AWS_REGION', nil) # e.g., 'us-west-2'
  config.bedrock_session_token = ENV.fetch('AWS_SESSION_TOKEN', nil) # For temporary credentials

  # --- Custom OpenAI Endpoint --- New in v1.2.0
  # Use this for Azure OpenAI, proxies, or self-hosted models via OpenAI-compatible APIs.
  # See the "Working with Models" guide for details.
  config.openai_api_base = ENV.fetch('OPENAI_API_BASE', nil) # e.g., "https://your-azure.openai.azure.com"

  # --- Default Models ---
  # Used by RubyLLM.chat, RubyLLM.embed, RubyLLM.paint if no model is specified.
  config.default_model = 'gpt-4.1-nano'               # Default: 'gpt-4.1-nano'
  config.default_embedding_model = 'text-embedding-3-small'  # Default: 'text-embedding-3-small'
  config.default_image_model = 'dall-e-3'            # Default: 'dall-e-3'

  # --- Connection Settings ---
  config.request_timeout = 120  # Request timeout in seconds (default: 120)
  config.max_retries = 3        # Max retries on transient network errors (default: 3)
  config.retry_interval = 0.1 # Initial delay in seconds (default: 0.1)
  config.retry_backoff_factor = 2 # Multiplier for subsequent retries (default: 2)
  config.retry_interval_randomness = 0.5 # Jitter factor (default: 0.5)
end
```

{: .note }
You only need to set the API keys for the providers you actually use. RubyLLM will raise a `ConfigurationError` if you attempt to use a provider whose key is not configured.

For advanced configuration options like `openai_api_base`, refer to the [Working with Models guide]({% link guides/models.md %}#connecting-to-custom-endpoints--using-unlisted-models).

## Verifying Installation

You can quickly verify your setup by running a simple query. Make sure you have configured at least one API key (like `openai_api_key` in the example below).

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

If this runs without errors and prints a response and model list, you're ready to go!

## Next Steps

Now that you've installed and configured RubyLLM, dive into the specific features:

*   [Getting Started Guide]({% link guides/getting-started.md %})
*   [Chatting with AI Models Guide]({% link guides/chat.md %})
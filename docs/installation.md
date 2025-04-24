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
*   Where to find configuration details.

## Prerequisites

*   Ruby 3.1 or later.
*   API keys for the AI providers you plan to use (e.g., OpenAI, Anthropic).

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

## Basic Configuration (Required)

RubyLLM needs API keys to communicate with AI providers. You **must** configure keys for the services you intend to use.

Here's a minimal example showing how to configure the OpenAI key:

```ruby
# config/initializers/ruby_llm.rb (in Rails) or at the start of your script
require 'ruby_llm'

RubyLLM.configure do |config|
  # Set keys for the providers you need. Using environment variables is best practice.
  config.openai_api_key = ENV.fetch('OPENAI_API_KEY', nil)
  # Add other keys like config.anthropic_api_key if needed
end
```

{: .note }
RubyLLM will raise a `ConfigurationError` if you attempt to use a provider whose key is not configured.

For a complete list of all configuration options, including setting default models, timeouts, custom endpoints, and using configuration contexts, please refer to the **[Configuration Guide]({% link configuration.md %})**.

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

If this runs without configuration errors and prints a response (or a specific API error like 'Invalid API key'), the gem is installed correctly.

## Next Steps

Now that you've installed RubyLLM:

*   Read the **[Configuration Guide]({% link configuration.md %})** for all setup options.
*   Check out the **[Getting Started Guide]({% link guides/getting-started.md %})** for basic usage examples.
*   Explore other **[Guides]({% link guides/index.md %})** for specific features like Chat, Tools, Embeddings, etc.
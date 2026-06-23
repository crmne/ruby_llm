---
layout: default
title: Rails Integration
nav_order: 1
has_children: true
description: Rails + AI made simple. Persist chats with ActiveRecord. Stream with Hotwire. Deploy with confidence.
redirect_from:
  - /guides/rails
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

*   How the RubyLLM persistence flow works inside a Rails request.
*   Why the flow creates and rolls back assistant messages the way it does.
*   What content validation constraints the flow imposes on your `Message` model.
*   How to set up a Rails application with the install generator.
*   How to configure RubyLLM in a Rails initializer.

RubyLLM treats Rails as a first-class home. Chats and messages become ActiveRecord models, attachments ride on ActiveStorage, and streaming plugs straight into Hotwire. This page explains the persistence flow that everything else builds on, then gets you to a working install. The deeper topics live in the child guides linked under [Going further](#going-further).

## Understanding the Persistence Flow

Before diving into setup, it's important to understand how RubyLLM handles message persistence in Rails. This design influences model validations and real-time UI updates.

### How It Works

When calling `chat_record.ask("What is the capital of France?")`, RubyLLM:

1. **Saves the user message** with the question content
2. **Calls the `complete` method**, which:
   - Makes the API call to the AI provider
   - Creates an empty assistant message:
     - **With streaming**: On receiving the first chunk
     - **Without streaming**: Before the API call
   - Processes the response:
     - **Success**: Updates the assistant message with content and metadata
     - **Failure**: Automatically destroys the empty assistant message

### Why This Design?

This approach optimizes for real-time experiences:

1. **Streaming optimized**: Creates DOM target on first chunk for immediate UI updates
2. **Turbo Streams ready**: Works with `after_create_commit` for real-time broadcasting
3. **Clean rollback**: Automatic cleanup on failure prevents orphaned records

### Content Validation Implications

You cannot use `validates :content, presence: true` on your `Message` model. The flow creates an empty assistant message before content arrives. See [Customizing the Persistence Flow]({% link _advanced/rails-persistence.md %}#customizing-the-persistence-flow) for an alternative approach.
{: .warning }

## Setting Up Your Rails Application

The fastest path to an AI-ready Rails app is the install generator. It writes the migrations, models, and initializer for you:

```bash
bin/rails generate ruby_llm:install
```

Then migrate and load the model registry:

```bash
bin/rails db:migrate
bin/rails ruby_llm:load_models # v1.13+
```

Your Rails app is now AI-ready. For everything the generators create, including the chat UI, conventional directory structure, and generator options, see [Generators and App Conventions]({% link _advanced/rails-generators.md %}).

## Configuring RubyLLM

Set up your API keys and other configuration in the initializer:

```ruby
# config/initializers/ruby_llm.rb
RubyLLM.configure do |config|
  config.openai_api_key = ENV['OPENAI_API_KEY']
  config.anthropic_api_key = ENV['ANTHROPIC_API_KEY']
  config.gemini_api_key = ENV['GEMINI_API_KEY']

  # For custom Model class names (defaults to 'Model')
  # config.model_registry_class = 'AIModel'
end
```

## Going further

Each part of Rails integration has its own focused guide:

*   [Persistence with acts_as]({% link _advanced/rails-persistence.md %}) - wire up `acts_as_chat`, `acts_as_message`, and friends, then work with chats, tools, attachments, and structured output.
*   [Streaming with Hotwire/Turbo]({% link _advanced/rails-streaming.md %}) - broadcast tokens in real time with Turbo Streams and background jobs.
*   [Generators and App Conventions]({% link _advanced/rails-generators.md %}) - the install and chat UI generators, view conventions, and the conventional app directory structure.
*   [Advanced Rails Configuration]({% link _advanced/rails-advanced-config.md %}) - provider overrides, custom contexts, raw provider payloads, and fiber-safe connections.

## Next Steps

*   [Chatting with AI Models]({% link _core_features/chat.md %}) - the core chat API your persisted models expose.
*   [Using Tools]({% link _core_features/tools.md %}) - let the AI call your Ruby code.
*   [Streaming Responses]({% link _core_features/streaming.md %}) - the streaming primitives behind Hotwire integration.
*   [Working with Models]({% link _reference/models.md %}) - the model registry and capability lookups.
*   [Error Handling]({% link _advanced/error-handling.md %}) - handle and recover from API failures.

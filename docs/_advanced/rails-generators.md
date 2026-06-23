---
layout: default
title: Generators and App Conventions
parent: "Rails Integration"
nav_order: 3
description: Scaffold chats, a chat UI, agents, tools, and schemas with RubyLLM's Rails generators and conventions.
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

*   What the `ruby_llm:install` and `ruby_llm:chat_ui` generators create for you.
*   How RubyLLM's conventional app directory structure is organized.
*   How to generate starter agents, tools, and schemas.
*   How the generated chat UI renders messages, tool calls, and tool results.
*   How to customize model names and set up ActiveStorage.

RubyLLM's Rails generators take you from an empty app to a working chat in two commands. They write migrations, models, controllers, jobs, views, and a conventional directory layout so your team starts from one shared structure. This guide walks through each generator and the conventions the generated code relies on.

## Quick Setup with Generator

The easiest way to get started is using the provided Rails generator:

```bash
bin/rails generate ruby_llm:install
```

The generator:
- Creates migrations for Chat, Message, ToolCall, and Model tables
- Sets up model files with appropriate `acts_as` declarations
- Installs ActiveStorage for file attachments
- Configures the database model registry
- Creates an initializer with sensible defaults
- Creates conventional AI app directories (`v1.14.0+`)

After running the generator:

```bash
bin/rails db:migrate
bin/rails ruby_llm:load_models # v1.13+
```

Your Rails app is now AI-ready!

## Adding a Chat UI

Want a ready-to-use chat interface? Run the chat UI generator:

```bash
bin/rails generate ruby_llm:chat_ui
```

This creates a complete chat interface with:
- **Controllers**: Handles chat and message creation with background processing
- **Views**: Modern UI with Turbo Streams for real-time updates
- **Jobs**: Background job for processing AI responses without blocking
- **Routes**: RESTful routes for chats and messages

After running the generator, start your server and visit `http://localhost:3000/chats` to begin chatting!

The UI generator also supports custom model names:

```bash
bin/rails generate ruby_llm:chat_ui chat:Conversation message:ChatMessage model:AIModel
```

## Conventional Directory Structure

RubyLLM's Rails generators now establish a default app structure:

```text
app/
|-- agents/
|-- prompts/
|-- schemas/
`-- tools/
```

The install generator creates these directories with `.gitkeep` files so teams start from one shared convention.

These are conventions, not hard requirements:

- Agents, tools, and schemas can live anywhere in your app autoload paths.
- Prompt lookup convention: the `instructions` class macro resolves `instructions.txt.erb` from the agent class name.

For prompt lookup, RubyLLM uses class name conventions:

- `WorkAssistant` -> `app/prompts/work_assistant/instructions.txt.erb`
- `Admin::SupportAgent` -> `app/prompts/admin/support_agent/instructions.txt.erb`

See the [Agents guide]({% link _advanced/agents.md %}#default-instructions-prompt) for how `instructions` rendering works.

## Rails Generators for Agents, Tools, and Schemas

Alongside `ruby_llm:install` and `ruby_llm:chat_ui`, Rails apps can generate starter classes for common AI building blocks:

```bash
bin/rails generate ruby_llm:agent Support
bin/rails generate ruby_llm:tool Weather
bin/rails generate ruby_llm:schema Product
```

What each generator creates:

- `ruby_llm:agent`: `app/agents/support_agent.rb` and `app/prompts/support_agent/instructions.txt.erb`
- `ruby_llm:tool`: `app/tools/weather_tool.rb` plus tool-specific chat UI partials under `app/views/messages/tool_calls` and `app/views/messages/tool_results`
- `ruby_llm:schema`: `app/schemas/product_schema.rb`

## Chat UI View Conventions

The generated chat UI follows one convention: each message partial uses the local that matches its partial name.

- `messages/_user.html.erb` gets `user`
- `messages/_assistant.html.erb` gets `assistant`
- `messages/_system.html.erb` gets `system`
- `messages/_tool.html.erb` gets `tool`
- `messages/_tool_calls.html.erb` gets `tool_calls`

This comes from Rails partial rendering: `render @chat.messages` calls `to_partial_path`, and Rails injects a local named after that partial.

For compatibility with model broadcasts (`broadcasts_to`), generated message partials also accept a `message` local as a fallback.

### Tool Call and Tool Result Partials

Tool-specific partials are generated under `app/views/messages/tool_calls` and `app/views/messages/tool_results`:

```text
app/views/messages/
|-- tool_calls/
|   |-- _default.html.erb
|   `-- _your_tool.html.erb
`-- tool_results/
    |-- _default.html.erb
    `-- _your_tool.html.erb
```

Locals passed to those partials:

- `messages/tool_calls/_your_tool.html.erb` receives `tool_calls` and `tool_call`
- `messages/tool_results/_your_tool.html.erb` receives `tool`

`ruby_llm:tool` creates `_your_tool.html.erb` files with the correct names so custom rendering hooks up automatically.

Using fixed locals keeps the templates dumb and predictable.

Turbo Stream templates used by the generated chat UI:

- `messages/create.turbo_stream.erb` resets the message form for `MessagesController#create`.

### Generator Options

The generator uses Rails-like syntax for custom model names:

```bash
# Default - creates Chat, Message, ToolCall, Model
bin/rails generate ruby_llm:install

bin/rails generate ruby_llm:install chat:Conversation message:ChatMessage
bin/rails generate ruby_llm:install chat:Discussion message:DiscussionMessage tool_call:FunctionCall model:AIModel

# Skip ActiveStorage if you don't need file attachments
bin/rails generate ruby_llm:install --skip-active-storage
```

The `name:ClassName` syntax follows Rails conventions - specify only what you want to customize.

For most apps, keep the default behavior (install ActiveStorage) so file attachments work out of the box. Use `--skip-active-storage` only when you're sure you won't send files to models.

## Setting Up ActiveStorage

The generator automatically configures ActiveStorage for file attachments. If you skipped it during generation, add it manually:

```bash
bin/rails active_storage:install
bin/rails db:migrate
```

Then add to your Message model:

```ruby
# app/models/message.rb
class Message < ApplicationRecord
  acts_as_message
  has_many_attached :attachments  # Required for file attachments
end
```

This `:attachments` association is only required on RubyLLM message records. The ActiveStorage attachments you pass to `with:` from your own models can use any name.

## Next Steps

*   [Persistence with acts_as]({% link _advanced/rails-persistence.md %}) - what the generated models do once they `acts_as_chat`.
*   [Streaming with Hotwire/Turbo]({% link _advanced/rails-streaming.md %}) - the streaming flow behind the generated chat UI.
*   [Agents]({% link _advanced/agents.md %}) - build on the generated agent and prompt conventions.
*   [Advanced Rails Configuration]({% link _advanced/rails-advanced-config.md %}) - provider overrides and custom contexts for the generated app.

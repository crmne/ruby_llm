---
layout: default
title: Rails Integration
nav_order: 1
has_children: true
description: Use the RubyLLM API with Active Record, Active Storage, Hotwire, and your existing Rails jobs.
redirect_from:
  - /guides/rails
---

# {{ page.title }}

{{ page.description }}
{: .fs-6 .fw-300 }

After reading this guide, you will know:

* How to install RubyLLM in a Rails application.
* How to use the conversation API on your own records.
* How to work with Active Storage attachments and Hotwire streaming.
* How to run agents and individual AI operations in background jobs.
* How message persistence affects your validations.

RubyLLM fits into the Rails application you already have. Chats and messages are your Active Record models. Files use Active Storage. Responses stream through Hotwire, and background work runs through your job backend.

The conversation API stays the same:

```ruby
chat = Chat.create!(model: "{{ site.models.default_chat }}")
response = chat.ask "Help me plan a Ruby study group."
response.content
```

`response` is a `RubyLLM::Message`. RubyLLM also saves it as your application's message record, together with tool calls, attachments, and usage. Read those records through `chat.messages`.

## Setting Up Your Rails Application

The install generator creates your chat and message models, migrations, and initializer:

```bash
bin/rails generate ruby_llm:install
bin/rails db:migrate
bin/rails ruby_llm:load_models
```

Configure a provider in the generated initializer:

```ruby
# config/initializers/ruby_llm.rb
RubyLLM.configure do |config|
  config.openai_api_key = ENV.fetch('OPENAI_API_KEY')
end
```

Use your application's secret storage for credentials. See [Configuration]({% link _getting_started/configuration.md %}) for other providers and defaults.

## The Same API on Your Records

Use the same chainable methods, tools, and schemas as plain Ruby:

```ruby
chat = Chat.create!(model: "{{ site.models.default_chat }}")
chat.with_instructions "Explain Ruby with short, runnable examples."
chat.ask "How does Enumerable#map work?"

chat.messages.count
chat.cost.total
```

Your application owns its `Chat` and `Message` models, so you can add users, permissions, titles, and other relationships. RubyLLM owns the supporting registry, tool-call, usage, and batch tables. See [Persistence with acts_as]({% link _advanced/rails-persistence.md %}) for the records and associations.

## Active Storage Attachments

Pass an attached file directly with `with:`:

```ruby
chat.ask "Summarize this report.", with: report.document
```

Here `report.document` is an Active Storage attachment. RubyLLM handles reading it and stores message attachments through the association created by the install generator. See [Attachments]({% link _core_features/attachments.md %}) for other file sources.

## Hotwire Streaming

Generate a working chat interface with controllers, views, Turbo Streams, and an Active Job:

```bash
bin/rails generate ruby_llm:chat_ui
```

Visit `/chats` in your running application. The generated files belong to your app, so you can adapt the interface and broadcasts. [Streaming with Hotwire/Turbo]({% link _advanced/rails-streaming.md %}) explains how the pieces fit together.

## Agents and Background Jobs

An agent configures your persisted chat when you load it in another process:

```ruby
class StudyAgent < RubyLLM::Agent
  chat_model Chat
  model "{{ site.models.default_chat }}"
  instructions "Help organize practical Ruby study sessions."
end

class StudyReplyJob < ApplicationJob
  def perform(chat_id, question)
    StudyAgent.find(chat_id).ask(question)
  end
end
```

```ruby
chat = StudyAgent.create!
StudyReplyJob.perform_later(chat.id, "Plan a session about Ruby blocks.")
```

Use your existing Active Job backend. See [Agents]({% link _advanced/agents.md %}) for persisted configuration and [Durable Agents]({% link _advanced/durable-agents.md %}) for work that pauses for approval or resumes after a deploy.

## Media and Document Processing

Individual AI operations work in Rails services and jobs too. For example, transcribe an attached recording and save the text:

```ruby
class TranscribeRecordingJob < ApplicationJob
  def perform(recording_id)
    recording = Recording.find(recording_id)
    transcript = RubyLLM.transcribe(recording.audio)
    recording.update!(transcript: transcript.text)
  end
end
```

This assumes your `Recording` model has an `audio` attachment and a `transcript` text column. The same pattern works for [OCR]({% link _core_features/ocr.md %}), [image generation]({% link _core_features/image-generation.md %}), and [moderation]({% link _core_features/moderation.md %}).

## Understanding the Persistence Flow

When you call `ask`, RubyLLM saves the user message, calls the provider, and saves the assistant's response. For streaming, it creates the assistant record before the first chunk arrives, giving Turbo Streams a stable target. A failed request removes its empty placeholder.

Allow assistant messages to have empty content. Streaming begins before text arrives, and tool calls can be valid responses without text. A blanket `validates :content, presence: true` on `Message` prevents these flows.

## Going further

* [Persistence with acts_as]({% link _advanced/rails-persistence.md %}) - records, associations, tools, usage, and custom model names.
* [Streaming with Hotwire/Turbo]({% link _advanced/rails-streaming.md %}) - broadcasts, cancellation, and message ordering.
* [Generators and App Conventions]({% link _advanced/rails-generators.md %}) - generated files and options.
* [Advanced Rails Configuration]({% link _advanced/rails-advanced-config.md %}) - provider overrides, tenant credentials, caching, and async connections.

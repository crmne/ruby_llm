---
layout: default
title: Rails Integration
seo:
  title: Rails AI Integration
nav_order: 14
has_children: true
description: "Add AI to a Rails app: use the RubyLLM API with Active Record, Active Storage, Hotwire, and your existing Rails jobs."
redirect_from:
  - /guides/rails
---

# {{ page.title }}

{{ page.description }}
{: .fs-6 .fw-300 }

After reading this guide, you will know:

* How to install RubyLLM in a Rails application.
* How to use the conversation API on your own records.
* How to run an agent against a saved chat.
* How to stream a reply from a background job, with or without the generator.
* How to retry and discard jobs on RubyLLM errors.
* How to run individual AI operations in jobs.
* How message persistence affects your validations.

RubyLLM fits into the Rails application you already have. Chats and messages are your Active Record models, files use Active Storage, replies stream through Hotwire, and background work runs on your job backend. This guide puts the support desk from the earlier guides into a Rails app.

## Setting Up Your Rails Application

The install generator creates your chat and message models, their migrations, RubyLLM's own tables, and an initializer:

```bash
bin/rails generate ruby_llm:install
bin/rails db:migrate
bin/rails ruby_llm:load_models
```

Generated primary and foreign keys follow your `config.generators` setting for `active_record.primary_key_type`, including `:uuid`. The default is `:bigint`.

Configure your providers in the generated initializer, reading keys from your credentials:

```ruby
# config/initializers/ruby_llm.rb
RubyLLM.configure do |config|
  config.openai_api_key = Rails.application.credentials.openai_api_key
end
```

See [Configuration]({% link _getting_started/configuration.md %}) for other providers and defaults.

JSON 3 rejects an option that older Rails versions pass to it. Rails 7.2.4 and 8.1.3 removed that option. On earlier versions, and on Rails 8.0, keep JSON 2 in your Gemfile with `gem "json", "< 3"`.
{: .note }

## The Same API on Your Records

Your `Chat` and `Message` models are yours: add associations, validations, and columns as you would to any model. The support desk's chats belong to a customer:

```ruby
class Chat < ApplicationRecord
  acts_as_chat
  belongs_to :customer
end
```

Everything a plain chat does, a record does too, and each message is saved as it arrives:

```ruby
chat = Chat.create!(customer: current_customer, model: "{{ site.models.default_chat }}")
chat.with_instructions "You answer customers of Acme Outfitters. Be brief and friendly."
chat.ask "Do you ship to Canada?"

chat.messages.count # => 3
chat.cost.total
```

`ask` returns a `RubyLLM::Message`, and RubyLLM saves it as your message record, with its tool calls, attachments, and usage. RubyLLM keeps its own data in eight supporting tables: the model registry, tool calls, usage, queued messages, chat files, batches, MCP credentials, and provider files. See [Persistence with acts_as]({% link _advanced/rails-persistence.md %}) for the records and associations.

## Active Storage Attachments

Pass an attachment with `with:`, as you pass a file in plain Ruby:

```ruby
chat.ask "What's wrong with this item?", with: ticket.photo
```

RubyLLM reads the file and stores the message's attachments through the association the install generator creates. See [Attachments]({% link _core_features/attachments.md %}) for other file sources.

`with_file_store` gives a chat its own files in Active Storage, so attachments and long tool results stop riding along with every request, and the model reads them with tools when it needs them. Attachments already in Active Storage share their blobs with the chat's files. See [File Stores]({% link _core_features/file-stores.md %}#files-in-rails).

## Agents on Saved Chats

The install generator writes `ApplicationAgent` with `chat_class Chat`, so agents create and find your records. The support agent reads its customer from the chat:

```ruby
# app/agents/support_agent.rb
class SupportAgent < ApplicationAgent
  model "{{ site.models.default_chat }}"
  instructions { "You answer #{chat.customer.name}, a customer of Acme Outfitters. Be brief and friendly." }
  tools { [LookupOrder.new(chat.customer), SearchDocs] }
end
```

`SupportAgent.create!` saves a new chat with the agent's instructions, and `SupportAgent.find` loads one and applies the agent's configuration, so any process can carry on the conversation:

```ruby
chat = SupportAgent.create!(customer: current_customer)
SupportAgent.find(chat.id).ask "Where is my order R-1042?"
```

See [Rails-Backed Agents]({% link _getting_started/agents.md %}#rails-backed-agents) for how instructions are saved.

## Streaming a Reply from a Job

A reply takes seconds, so answer in a job and stream it to the page. Turn on message broadcasting:

```ruby
# config/initializers/ruby_llm.rb
RubyLLM.configure do |config|
  config.broadcast_messages = true
end
```

The controller saves the customer's message and starts a job to answer it:

```ruby
class MessagesController < ApplicationController
  def create
    chat = current_customer.chats.find(params[:chat_id])
    chat.ask_later(params[:content])
    SupportReplyJob.perform_later(chat.id)
    head :accepted
  end
end
```

The job lets the agent finish the conversation, broadcasting each chunk as it arrives:

```ruby
class SupportReplyJob < ApplicationJob
  def perform(chat_id)
    chat = SupportAgent.find(chat_id)
    chat.complete(&:broadcast)
    retry_job wait: 1.minute if chat.running?
  end
end
```

The chat's page subscribes to its stream and renders its messages:

```erb
<%# app/views/chats/show.html.erb %>
<%= turbo_stream_from @chat %>
<div id="messages"><%= render @chat.messages %></div>
```

`complete` answers the message, and each chunk's `broadcast` appends it to the assistant message on the page. A message sent while a reply runs waits in the queue, because `ask_later` queues it while a run holds the chat, and the running job answers it before it lets the chat go. The job you enqueued for it finds the chat running and returns. Its retry a minute later only matters when the running job died, since its claim on the chat expires within a minute.

`render @chat.messages` picks a partial per message: `messages/_system`, `_user`, `_assistant`, `_tool`, and `_tool_calls`. Write the ones your page shows. The assistant partial holds the target chunks land in. Rendering a collection passes it `assistant`, and a broadcast passes it `message`, so it accepts both:

```erb
<%# app/views/messages/_assistant.html.erb %>
<% assistant ||= local_assigns[:message] %>
<div id="<%= dom_id(assistant) %>">
  <div id="<%= dom_id(assistant) %>_stream"><%= assistant.content %></div>
</div>
```

[Streaming with Hotwire]({% link _advanced/rails-streaming.md %}) covers cancelling a reply and message ordering.

To skip the wiring, generate a working chat interface with controllers, views, and a job:

```bash
bin/rails generate ruby_llm:chat_ui
```

Visit `/chats` in your running application. The message form has the same model picker as the new-chat form, so you can switch a chat's model mid-conversation: the reply to that message and every reply after it use the new model. The generated files belong to your app, so change them as you like.

## Handling Errors in Jobs

RubyLLM retries rate limits, timeouts, and server errors itself, up to `config.max_retries` times. When those retries run out, the error reaches your job. Let Active Job decide what happens next:

```ruby
class SupportReplyJob < ApplicationJob
  retry_on RubyLLM::RateLimitError, RubyLLM::ServiceUnavailableError, wait: :polynomially_longer, attempts: 5
  discard_on RubyLLM::BadRequestError

  def perform(chat_id)
    SupportAgent.find(chat_id).complete(&:broadcast)
  end
end
```

A rate limit or an outage passes, so retry later. A bad request fails the same way every time, so discard the job and report it. Retrying is safe because the customer's message is already saved: `complete` picks up where the conversation stopped instead of asking twice. A job that gives up leaves any queued message waiting until the next `complete`, so report the failure, or enqueue the job again when the chat has `queued_messages`.

To tell the customer, add a `reply_error` string column to your chats table. When a reply fails, `complete` saves a short message for them there before it raises, and the next run clears it, so the chat's page can show it whenever it loads. The I18n keys `ruby_llm.reply_error.failed` and `ruby_llm.reply_error.too_long` hold the text. The [chat UI generator]({% link _advanced/rails-generators.md %}#adding-a-chat-ui) adds the column.

See [Error Handling]({% link _advanced/error-handling.md %}) for every error class, and [Durable Agents]({% link _advanced/durable-agents-overview.md %}) for jobs that pause for approvals and survive deploys.

## Individual Operations in Jobs

Individual AI operations work in Rails services and jobs too. The support desk transcribes voicemails as they arrive and opens a ticket:

```ruby
class TranscribeVoicemailJob < ApplicationJob
  def perform(voicemail)
    transcript = RubyLLM.transcribe(voicemail.audio)
    voicemail.customer.tickets.create!(body: transcript.text, channel: "phone")
  end
end
```

`voicemail.audio` is an Active Storage attachment, passed straight to `transcribe`. The same pattern works for [OCR]({% link _getting_started/ocr.md %}) on uploaded invoices, [moderation]({% link _getting_started/moderation.md %}) of incoming messages, and [image generation]({% link _getting_started/image-generation.md %}).

## Message Persistence and Validations

When you call `ask`, RubyLLM saves the user message, calls the provider, and saves the assistant's answer. When streaming, it creates the assistant record before the first chunk arrives, so Turbo has a target to append to. A failed request removes that empty placeholder, and so does an error raised by your streaming block.

Allow assistant messages with empty content. Streaming starts before any text arrives, and a message that only calls tools has no text. A blanket `validates :content, presence: true` on `Message` breaks both.
{: .warning }

Only one process runs a chat at a time. A job that finds the chat claimed returns without doing anything, and a crashed job's claim lasts until it expires, so nothing resumes that work until another `complete` runs after that. A tool call the crash cut off doesn't run again: the model hears it may have partly run. See [One Process at a Time]({% link _advanced/durable-agents.md %}#one-process-at-a-time), [Resuming a Crashed Run]({% link _advanced/durable-agents.md %}#resuming-a-crashed-run), and [What a Crash Repeats]({% link _advanced/durable-agents.md %}#what-a-crash-repeats).

## Next Steps

* [Persistence with acts_as]({% link _advanced/rails-persistence.md %}): records, associations, tools, usage, and custom model names.
* [Streaming with Hotwire]({% link _advanced/rails-streaming.md %}): partials, cancellation, and message ordering.
* [Durable Agents]({% link _advanced/durable-agents-overview.md %}): approvals, deploys, and crashed runs.
* [Generators and App Conventions]({% link _advanced/rails-generators.md %}): generated files and options.
* [Advanced Rails Configuration]({% link _advanced/rails-advanced-config.md %}): provider overrides, tenant credentials, and caching.

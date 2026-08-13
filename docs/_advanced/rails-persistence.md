---
layout: default
title: Persistence with acts_as
parent: "Rails Integration"
nav_order: 1
description: Persist application-owned chats and messages while RubyLLM manages its supporting records.
---

# {{ page.title }}

{{ page.description }}
{: .fs-6 .fw-300 }

After reading this guide, you will know:

* How to add RubyLLM to your `Chat` and `Message` models.
* Which records belong to your application and which RubyLLM manages internally.
* How persisted usage, tool calls, models, and batches behave.
* How to use custom or namespaced chat and message classes.

## Two Application Models

Your application owns the conversation: chats and messages. Those are the records where application concerns such as users, permissions, titles, content, retention, and attachments belong.

```ruby
# app/models/chat.rb
class Chat < ApplicationRecord
  acts_as_chat

  belongs_to :user, optional: true
end

# app/models/message.rb
class Message < ApplicationRecord
  acts_as_message
  has_many_attached :attachments

  validates :role, presence: true
end
```

That is the complete application-facing persistence setup. There is no `Model`, `ToolCall`, `UsageEntry`, or `Batch` model to add to `app/models`.

RubyLLM owns four supporting tables under the `ruby_llm_` prefix:

* `ruby_llm_models` for the model registry.
* `ruby_llm_tool_calls` for provider tool requests and their result links.
* `ruby_llm_usage_entries` for retry- and cancellation-safe cost and usage tracking.
* `ruby_llm_batches` for provider-side batch state.

They are regular tables installed by migrations, not a Rails engine. Their record classes are implementation details; use the public RubyLLM APIs described below.

Do not validate message content as always present. Streaming creates an empty assistant message before content arrives, and a valid assistant message can contain tool calls without text.
{: .warning }

## Working with Persisted Chats

An `acts_as_chat` record exposes the regular chat API and persists transcript changes automatically:

```ruby
chat = Chat.create!(model: '{{ site.models.default_chat }}', user: current_user)

response = chat.ask("What is the capital of France?")

response.content          # => "The capital of France is Paris."
chat.messages.last.content
chat.messages.count       # => 2
```

The flow saves the user message, creates an assistant message, performs the provider operation, and fills the assistant message on success. If the operation fails before producing a useful message, RubyLLM removes the empty assistant record. Usage already incurred by a retry or cancellation remains in the usage ledger.

System instructions are messages too:

```ruby
chat.with_instructions("You are a concise Ruby expert.")
chat.with_instructions("Use short bullet points.", append: true)

chat.messages.where(role: :system)
```

Runtime-only settings such as fallbacks, tools, temperature, and callbacks live on the memoized `to_llm` chat. Reapply them after loading a fresh record, or define them in an [Agent]({% link _advanced/agents.md %}).

```ruby
chat.with_fallbacks("gpt-4.1-mini", "claude-haiku-4-5")
chat.with_temperature(0.2)
chat.ask("Summarize this conversation.")
```

## Model Storage

The chat belongs to a model record in RubyLLM's internal registry. The familiar readers still expose the provider-facing identity:

```ruby
chat = Chat.create!(model: '{{ site.models.openai_standard }}')

chat.model_id             # => "{{ site.models.openai_standard }}"
chat.provider             # => "openai"
chat.model                # => #<RubyLLM::ActiveRecord::Model ...>
chat.model.context_window
```

The registry itself is persisted internally. Query and refresh it through `RubyLLM.models`:

```ruby
RubyLLM.models.find('{{ site.models.openai_standard }}', :openai)
RubyLLM.models.by_provider(:anthropic)
RubyLLM.models.refresh!
```

There is no application-owned `Model` class or configurable registry model class. `acts_as_chat` defines the `model` association against RubyLLM's private record, preserving referential integrity without putting provider metadata in your application models.

## Cost and Usage Tracking

Usage belongs to provider work, not to the transcript. RubyLLM therefore persists one normalized entry for every physical attempt, including automatic retries and cancelled streams that never produced a message.

```ruby
response = chat.ask("Explain Ruby fibers.")

response.tokens.input    # aggregate of the attempts that produced it
response.tokens.output
response.cost.total
chat.tokens.input         # includes retries and cancelled attempts
chat.cost.total           # includes retries and cancelled attempts
```

An internal entry links to its resulting message when one exists. A failed retry or cancelled generation can remain linked only to the chat. Per-attempt details are available through `usage.ruby_llm` instrumentation rather than a second public usage API.

Token buckets and cost components are numeric columns in `ruby_llm_usage_entries`; cost details are not stored as JSON. This freezes the price calculated when an attempt finishes and keeps the ledger suitable for database aggregation. Message token and cost columns from older RubyLLM versions remain readable as a compatibility fallback, but new installs do not add them.

See [Cost and Usage Tracking]({% link _core_features/cost-and-usage-tracking.md %}) for entry statuses, incomplete totals, cancellation behavior, and instrumentation.

## Tools

Tools remain ordinary Ruby classes:

```ruby
class Weather < RubyLLM::Tool
  description "Gets current weather for a city"
  parameter :city

  def execute(city:)
    "Sunny in #{city}"
  end
end

chat.with_tools(Weather)
chat.ask("What is the weather in Berlin?")
```

RubyLLM persists provider tool requests internally and exposes public `RubyLLM::ToolCall` values from the message:

```ruby
message = chat.messages.find(&:tool_call?)
tool_call = message.tool_calls.values.first

tool_call.id
tool_call.name
tool_call.arguments
message.tool_results
```

The tool result itself is an application-owned message with the `tool` role. The internal tool-call row only preserves the provider request and links it to that result message.

## Batches

Submitting persisted chats automatically stores the provider batch state internally:

```ruby
chats = tickets.map do |ticket|
  Chat.create!(model: "claude-haiku-4-5").ask_later(ticket.body)
end

batch = RubyLLM.batch(chats)
BatchPollJob.perform_later(batch.id)
```

Look the batch up with the public value API from another process:

```ruby
batch = RubyLLM::Batch.find(batch_id)
batch.refresh

if batch.complete?
  batch.messages # appends each result to its persisted chat
end
```

No application `Batch` model is required. See [Batch Processing]({% link _advanced/batches.md %}) for polling and multi-round tool workflows.

## Attachments and Structured Output

With Active Storage on your message model, files passed to `ask` are persisted with the user message:

```ruby
chat.ask("What is in this file?", with: params[:uploaded_file])
chat.ask("Compare these", with: project.documents)
```

Structured output is stored as JSON text in the application message content:

```ruby
class PersonSchema < RubyLLM::Schema
  string :name
  integer :age
end

response = chat.with_schema(PersonSchema).ask("Generate a person")
response.content                 # parsed Hash
JSON.parse(chat.messages.last.content)
```

## Separate User and LLM Transcripts

The association passed to `acts_as_chat` is the transcript RubyLLM persists and sends to providers. Point it at a separate association when your user-visible transcript has different retention, compaction, moderation, or redaction rules:

```ruby
class Conversation < ApplicationRecord
  has_many :messages

  acts_as_chat messages: :llm_messages,
               message_class: "LlmMessage"
end
```

Your UI can render `conversation.messages` while RubyLLM works with `conversation.llm_messages`.

## Custom and Namespaced Models

Only the chat/message association needs mapping:

```ruby
class Conversation < ApplicationRecord
  acts_as_chat messages: :chat_messages,
               message_class: "ChatMessage"
end

class ChatMessage < ApplicationRecord
  acts_as_message chat: :conversation,
                  chat_class: "Conversation"
end
```

Specify the foreign key when Rails cannot infer it:

```ruby
module Support
  class Conversation < ApplicationRecord
    acts_as_chat messages: :entries,
                 message_class: "Support::Entry",
                 messages_foreign_key: :conversation_id
  end

  class Entry < ApplicationRecord
    acts_as_message chat: :conversation,
                    chat_class: "Support::Conversation",
                    chat_foreign_key: :conversation_id
  end
end
```

Internal usage and tool-call references are polymorphic, so custom names and primary-key types do not require matching application models for RubyLLM's supporting records.

## Extending Your Models

Chats and messages remain normal ActiveRecord models:

```ruby
class Chat < ApplicationRecord
  acts_as_chat

  belongs_to :user
  has_many :favorites, dependent: :destroy

  scope :recent, -> { order(updated_at: :desc) }

  def summary
    messages.last(2).map(&:content).join(" … ")
  end
end
```

Keep transcript content and application relationships in these models. Observe provider cost and usage through `usage.ruby_llm` instrumentation instead of copying RubyLLM's internal supporting models into your domain.

## Next Steps

* [Cost and Usage Tracking]({% link _core_features/cost-and-usage-tracking.md %}) - understand attempts, retries, cancellations, and incomplete totals.
* [Streaming with Hotwire/Turbo]({% link _advanced/rails-streaming.md %}) - broadcast persisted responses in real time.
* [Generators and App Conventions]({% link _advanced/rails-generators.md %}) - see exactly what installation creates.
* [Working with Models]({% link _reference/models.md %}) - inspect and refresh the internal registry through the public API.

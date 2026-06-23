---
layout: default
title: Persistence with acts_as
parent: "Rails Integration"
nav_order: 1
description: Persist chats, messages, tool calls, and model metadata with ActiveRecord using the acts_as helpers.
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

*   How to add RubyLLM capabilities to your models with the `acts_as` helpers.
*   How to ask questions, track tokens and costs, and add system instructions on persisted chats.
*   How to use tools, file attachments, and structured output with ActiveRecord-backed chats.
*   How to customize model and association names, including for namespaced models.
*   How to override the persistence flow when you need content validations.

The `acts_as` helpers turn ordinary ActiveRecord models into RubyLLM chats and messages. Once a model `acts_as_chat`, it gains the full chat API - `ask`, `with_tool`, `with_schema`, and the rest - while persisting every message to your database automatically. Start by declaring the helpers, then everything else in this guide builds on those four models.

## Setting Up Models with `acts_as` Helpers

Add RubyLLM capabilities to your models:

### With Model Registry (Default for new apps)

```ruby
# app/models/chat.rb
class Chat < ApplicationRecord
  # New API style - uses Rails association names as primary parameters
  acts_as_chat # Defaults: messages: :messages, model: :model

  # Or with custom associations:
  # acts_as_chat messages: :chat_messages,
  #              model: :ai_model

  belongs_to :user, optional: true
end

# app/models/message.rb
class Message < ApplicationRecord
  # New API style - uses Rails association names
  acts_as_message # Defaults: chat: :chat, tool_calls: :tool_calls, model: :model

  # Or with custom associations:
  # acts_as_message chat: :conversation,
  #                 tool_calls: :function_calls

  # Note: Do NOT add "validates :content, presence: true"
  validates :role, presence: true
  validates :chat, presence: true
end

# app/models/tool_call.rb
class ToolCall < ApplicationRecord
  acts_as_tool_call # Defaults: message: :message, result: :result
end

# app/models/model.rb
class Model < ApplicationRecord
  acts_as_model # Defaults: chats: :chats
end
```

## Working with Chats

### Basic Chat Operations

The `acts_as_chat` helper provides all standard chat methods:

```ruby
chat_record = Chat.create!(model: '{{ site.models.default_chat }}', user: current_user)

# Ask a question - the persistence flow runs automatically
begin
  # This saves the user message, then calls complete() which:
  # 1. Creates an empty assistant message
  # 2. Makes the API call
  # 3. Updates the message on success, or destroys it on failure
  response = chat_record.ask "What is the capital of France?"

  assistant_message_record = chat_record.messages.last
  puts assistant_message_record.content # => "The capital of France is Paris."
rescue RubyLLM::Error => e
  puts "API Call Failed: #{e.message}"
  # The empty assistant message is automatically cleaned up on failure
end

chat_record.ask "Tell me more about that city"

puts "Conversation length: #{chat_record.messages.count}" # => 4
```

### Separate User and LLM Transcripts

The `acts_as_chat` association is the transcript RubyLLM persists and sends to the provider. The optional `ruby_llm:chat_ui` generator renders that same association by default.

If your app needs separate user-visible and model-visible transcripts, point `acts_as_chat` at the model-visible association. This is useful for chat compaction, moderation, redaction, or any workflow where the LLM should see a different transcript from the user. In this setup, `messages` is whatever you show the user, while `llm_messages` is whatever you show the LLM:

For plain Ruby chats, see [Replacing the LLM Transcript]({% link _core_features/chat.md %}#advanced-replacing-the-llm-transcript).

```ruby
class Conversation < ApplicationRecord
  has_many :messages

  acts_as_chat messages: :llm_messages,
               message_class: "LlmMessage"
end
```

Your custom UI renders `conversation.messages`. RubyLLM persists and sends `conversation.llm_messages`:

```ruby
conversation.llm_messages.destroy_all
conversation.llm_messages.create!(role: :system, content: summary)
conversation.llm_messages.create!(role: :user, content: latest_user_message)

conversation.complete
```

### Token Usage and Costs

Persisted chats and messages expose the same normalized token and cost helpers as regular RubyLLM objects:

```ruby
message = chat_record.messages.last

message.tokens.input       # Standard input tokens
message.tokens.output      # Billable output tokens
message.tokens.cache_read  # Prompt cache reads
message.tokens.cache_write # Prompt cache writes
message.finish_reason      # Provider-reported reason the model stopped

message.cost.total
message.cost.thinking # When the model has distinct reasoning-token pricing
chat_record.cost.total
```

`cache_read_tokens` and `cache_write_tokens` are aliases for the existing v1.9 `cached_tokens` and `cache_creation_tokens` columns, so apps that already ran the v1.9 migration do not need another migration for these names.

RubyLLM normalizes provider-specific cache accounting before persisting token counts. See [Token Usage and Cost]({% link _core_features/chat-tokens.md %}) for the provider comparison table.

`finish_reason` is persisted when your message table has a string column with that name. New installs include it, and the upgrade generator adds it for existing apps.

### Database Model Registry

When using the Model registry (created by default by the generator), your chats and messages get associations to model records:

```ruby
# String automatically resolves to Model record
chat = Chat.create!(model: '{{ site.models.openai_standard }}')
chat.model # => #<Model model_id: "{{ site.models.openai_standard }}", provider: "openai">
chat.model.name # => "GPT-5.4"
chat.model.context_window # => 1050000
chat.model.supports_vision # => true

# Populate/refresh models from models.json (v1.13+)
bin/rails ruby_llm:load_models

Chat.joins(:model).where(models: { provider: 'anthropic' })
Model.left_joins(:chats).group(:id).order('COUNT(chats.id) DESC')

Model.where(supports_functions: true)
Model.where(supports_vision: true)
```

If the model registry table is empty (or not available yet), RubyLLM falls back to `models.json` for lookups (v1.13+).

### System Instructions

System prompts are persisted as messages with the `system` role:

```ruby
chat_record = Chat.create!(model: '{{ site.models.default_chat }}')

chat_record.with_instructions("You are a Ruby expert.")

# By default, with_instructions replaces the active system instruction
chat_record.with_instructions("You are a concise Ruby expert.")

# Append only when you intentionally want multiple system prompts
chat_record.with_instructions("Use short bullet points.", append: true)

system_message = chat_record.messages.find_by(role: :system)
puts system_message.content # => "You are a concise Ruby expert."
```

### Using Tools

Tools are Ruby classes that the AI can call. While the tool classes themselves aren't persisted, the tool calls and their results are saved as messages:

```ruby
class Weather < RubyLLM::Tool
  description "Gets current weather for a location"
  param :city, desc: "City name"

  def execute(city:)
    "The weather in #{city} is sunny and 22°C."
  end
end

chat_record = Chat.create!(model: '{{ site.models.default_chat }}')
chat_record.with_tool(Weather)

response = chat_record.ask("What's the weather in Paris?")

# Check persisted messages:
# 1. User message: "What's the weather in Paris?"
# 2. Assistant message with tool_calls (the AI's decision to use the tool)
# 3. Tool result message (the output from Weather#execute)
puts chat_record.messages.count # => 3

# The tool call details are stored in the ToolCall table
tool_call = chat_record.messages.second.tool_calls.first
puts tool_call.name # => "Weather"
puts tool_call.arguments # => {"city" => "Paris"}
```

### File Attachments

Send files to AI models using ActiveStorage:

```ruby
chat_record = Chat.create!(model: '{{ site.models.anthropic_current }}')

# Send a single file - type automatically detected
chat_record.ask("What's in this file?", with: "app/assets/images/diagram.png")

# Send multiple files of different types - all automatically detected
chat_record.ask("What are in these files?", with: [
  "app/assets/documents/report.pdf",
  "app/assets/images/chart.jpg",
  "app/assets/text/notes.txt",
  "app/assets/audio/recording.mp3"
])

# Works with file uploads from forms
chat_record.ask("Analyze this file", with: params[:uploaded_file])

# Works with existing ActiveStorage attachments
chat_record.ask("What's in this document?", with: user.profile_document) # has_one_attached
chat_record.ask("Compare these documents", with: project.documents)      # has_many_attached
```

File types are automatically detected from extensions or MIME types.

### Structured Output

Generate and persist structured responses:

```ruby
class PersonSchema < RubyLLM::Schema
  string :name
  integer :age
  string :city, required: false
end

chat_record = Chat.create!(model: '{{ site.models.default_chat }}')
response = chat_record.with_schema(PersonSchema).ask("Generate a person from Paris")

# The structured response is automatically parsed as a Hash
puts response.content # => {"name" => "Marie", "age" => 28, "city" => "Paris"}

# But it's stored as JSON in the database
message = chat_record.messages.last
puts message.content # => "{\"name\":\"Marie\",\"age\":28,\"city\":\"Paris\"}"
puts JSON.parse(message.content) # => {"name" => "Marie", "age" => 28, "city" => "Paris"}
```

Schemas work in multi-turn conversations:

```ruby
chat_record.with_schema(PersonSchema)
person = chat_record.ask("Generate a French person")

# Remove the schema for analysis
chat_record.with_schema(nil)
analysis = chat_record.ask("What's interesting about this person?")

puts chat_record.messages.count # => 4
```

## Customizing Models

The `acts_as` helpers integrate seamlessly with standard Rails patterns. Add associations, validations, scopes, and callbacks as needed.

### Using Custom Model Names

If your application uses different model names, you can configure the `acts_as` helpers accordingly:

#### With Model Registry

```ruby
# app/models/conversation.rb (instead of Chat)
class Conversation < ApplicationRecord
  acts_as_chat messages: :chat_messages,  # Association name
               model: :ai_model

  belongs_to :user, optional: true
end

# app/models/chat_message.rb (instead of Message)
class ChatMessage < ApplicationRecord
  acts_as_message chat: :conversation,  # Association name
                  tool_calls: :ai_tool_calls,
                  model: :ai_model
end

# app/models/ai_tool_call.rb (instead of ToolCall)
class AiToolCall < ApplicationRecord
  acts_as_tool_call message: :chat_message,
                    result: :result
end

# app/models/ai_model.rb (instead of Model)
class AiModel < ApplicationRecord
  acts_as_model chats: :conversations
end
```

The new API follows Rails association inference: the association name determines the default foreign key, and the `*_class` options only change the class name. For example, `tool_calls: :ai_tool_calls` uses `ai_tool_call_id`, while `tool_call_class: 'AiToolCall'` by itself still uses `tool_call_id`.

#### Namespaced Models Example

For namespaced models, you'll need to specify class names explicitly:

```ruby
# app/models/admin/bot_chat.rb
module Admin
  class BotChat < ApplicationRecord
    acts_as_chat messages: :bot_messages,
                 message_class: 'Admin::BotMessage'  # Required for namespace
  end
end

# app/models/admin/bot_message.rb
module Admin
  class BotMessage < ApplicationRecord
    acts_as_message chat: :bot_chat,
                    chat_class: 'Admin::BotChat',
                    tool_calls: :bot_tool_calls,
                    tool_call_class: 'Admin::BotToolCall'
  end
end

# app/models/admin/bot_tool_call.rb
module Admin
  class BotToolCall < ApplicationRecord
    acts_as_tool_call message: :bot_message,
                      message_class: 'Admin::BotMessage'
  end
end
```

If you choose prefixed association names such as `llm_tool_calls`, configure the reverse association the same way you would in Rails:

```ruby
class Llm::ToolCall < ApplicationRecord
  acts_as_tool_call message: :llm_message,
                    message_class: 'Llm::Message',
                    result_foreign_key: :llm_tool_call_id
end
```

### Common Customizations

Extend your models with standard Rails patterns:

```ruby
# app/models/chat.rb
class Chat < ApplicationRecord
  acts_as_chat

  belongs_to :user
  has_many :favorites, dependent: :destroy

  scope :recent, -> { order(updated_at: :desc) }
  scope :with_responses, -> { joins(:messages).where(messages: { role: 'assistant' }).distinct }

  def summary
    messages.last(2).map(&:content).join(' ... ')
  end

  after_create :notify_administrators

  private

  def notify_administrators
    # Custom logic
  end
end
```

## Advanced Topics

### Handling Edge Cases

#### Automatic Cleanup

RubyLLM automatically cleans up empty assistant messages when API calls fail. This prevents orphaned records that could cause issues with providers that reject empty content.

#### Provider Content Restrictions

Some providers (like Gemini) reject conversations with empty message content. RubyLLM's automatic cleanup ensures this isn't an issue during normal operation.

### Customizing the Persistence Flow

For applications requiring content validations, override the default persistence methods:

```ruby
# app/models/chat.rb
class Chat < ApplicationRecord
  acts_as_chat

  private

  def persist_new_message
    # Create a new message object but don't save it yet
    @message = messages.new(role: :assistant)
  end

  def persist_message_completion(message)
    return unless message

    # Fill in attributes and save once we have content
    @message.assign_attributes(
      content: message.content,
      model: Model.find_by(model_id: message.model_id),
      input_tokens: message.tokens.input,
      output_tokens: message.tokens.output,
      cached_tokens: message.tokens.cache_read,
      cache_creation_tokens: message.tokens.cache_write
    )

    @message.save!

    persist_tool_calls(message.tool_calls) if message.tool_calls.present?
  end

  def persist_tool_calls(tool_calls)
    tool_calls.each_value do |tool_call|
      attributes = tool_call.to_h
      attributes[:tool_call_id] = attributes.delete(:id)
      @message.tool_calls.create!(**attributes)
    end
  end
end

# app/models/message.rb
class Message < ApplicationRecord
  acts_as_message

  # Now you can safely add this validation
  validates :content, presence: true
end
```

This approach trades streaming UI updates for content validation support:
- ✅ Content validations work
- ✅ No empty messages in database
- ❌ No DOM target for streaming before API response

## Next Steps

*   [Streaming with Hotwire/Turbo]({% link _advanced/rails-streaming.md %}) - broadcast persisted messages to the browser in real time.
*   [Advanced Rails Configuration]({% link _advanced/rails-advanced-config.md %}) - provider overrides, custom contexts, and raw provider payloads.
*   [Token Usage and Cost]({% link _core_features/chat-tokens.md %}) - the full token and cost reference.
*   [Working with Models]({% link _reference/models.md %}) - query and refresh the model registry.

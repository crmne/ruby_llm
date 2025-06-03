---
layout: default
title: Rails Integration
parent: Guides
nav_order: 5
permalink: /guides/rails
---

# Rails Integration
{: .no_toc }

RubyLLM offers seamless integration with Ruby on Rails applications through helpers for ActiveRecord models. This allows you to easily persist chat conversations, including messages and tool interactions, directly in your database.
{: .fs-6 .fw-300 }

## Table of contents
{: .no_toc .text-delta }

1. TOC
{:toc}

---

After reading this guide, you will know:

*   How to set up ActiveRecord models for persisting chats and messages.
*   How the RubyLLM persistence flow works with Rails applications.
*   How to use `acts_as_chat` and `acts_as_message` with your models.
*   How to integrate streaming responses with Hotwire/Turbo Streams.
*   How to customize the persistence behavior for validation-focused scenarios.

## Understanding the Persistence Flow

Before diving into setup, it's important to understand how RubyLLM handles message persistence in Rails. This design influences model validations and real-time UI updates.

### How It Works

When you call `chat_record.ask("What is the capital of France?")`, RubyLLM follows these steps:

1. **Save the user message** with the question content.
2. **Call the `complete` method**, which:
   - **Creates an empty assistant message** with blank content via the `on_new_message` callback
   - **Makes the API call** to the AI provider using the conversation history
   - **Process the response:**
     - **On success**: Updates the assistant message with content, token counts, and tool call information via the `on_end_message` callback
     - **On failure**: Cleans up by automatically destroying the empty assistant message

### Why This Design?

This two-phase approach (create empty → update with content) is intentional and optimizes for real-time UI experiences:

1. **Streaming-first design**: By creating the message record before the API call, your UI can immediately show a "thinking" state and have a DOM target ready for incoming chunks.
2. **Turbo Streams compatibility**: Works perfectly with `after_create_commit { broadcast_append_to... }` for real-time updates.
3. **Clean rollback on failure**: If the API call fails, the empty assistant message is automatically removed, preventing orphaned records that could cause issues with providers like Gemini that reject empty messages.

### Content Validation Implications

This approach has one important consequence: **you cannot use `validates :content, presence: true`** on your Message model because the initial creation step would fail validation. Later in the guide, we'll show an alternative approach if you need content validations.

## Setting Up Your Rails Application

### Database Migrations

First, generate migrations for your `Chat` and `Message` models. You'll also need a `ToolCall` model if you plan to use [Tools]({% link guides/tools.md %}).

```bash
# Generate basic models and migrations
rails g model Chat model_id:string user:references # Example user association
rails g model Message chat:references role:string content:text model_id:string input_tokens:integer output_tokens:integer tool_call:references
rails g model ToolCall message:references tool_call_id:string:index name:string arguments:jsonb
```

Adjust the migrations as needed (e.g., `null: false` constraints, `jsonb` type for PostgreSQL).

```ruby
# db/migrate/YYYYMMDDHHMMSS_create_chats.rb
class CreateChats < ActiveRecord::Migration[7.1]
  def change
    create_table :chats do |t|
      t.string :model_id
      t.references :user # Optional: Example association
      t.timestamps
    end
  end
end

# db/migrate/YYYYMMDDHHMMSS_create_messages.rb
class CreateMessages < ActiveRecord::Migration[7.1]
  def change
    create_table :messages do |t|
      t.references :chat, null: false, foreign_key: true
      t.string :role
      t.text :content
      # Optional fields for tracking usage/metadata
      t.string :model_id
      t.integer :input_tokens
      t.integer :output_tokens
      t.references :tool_call # Links tool result message to the initiating call
      t.timestamps
    end
  end
end

# db/migrate/YYYYMMDDHHMMSS_create_tool_calls.rb
# (Only needed if using tools)
class CreateToolCalls < ActiveRecord::Migration[7.1]
  def change
    create_table :tool_calls do |t|
      t.references :message, null: false, foreign_key: true # Assistant message making the call
      t.string :tool_call_id, null: false, index: { unique: true } # Provider's ID for the call
      t.string :name, null: false
      t.jsonb :arguments, default: {} # Use jsonb for PostgreSQL
      t.timestamps
    end
  end
end
```

Run the migrations: `rails db:migrate`

### ActiveStorage Setup for Attachments (Optional)

If you want to use attachments (images, audio, PDFs) with your AI chats, you need to set up ActiveStorage:

```bash
# Only needed if you plan to use attachments
rails active_storage:install
rails db:migrate
```

Then add the attachments association to your Message model:

```ruby
# app/models/message.rb
class Message < ApplicationRecord
  acts_as_message # Basic RubyLLM integration

  # Optional: Add this line to enable attachment support
  has_many_attached :attachments
end
```

This setup is completely optional - your RubyLLM Rails integration works fine without it if you don't need attachment support.

### Configure RubyLLM

Ensure your RubyLLM configuration (API keys, etc.) is set up, typically in `config/initializers/ruby_llm.rb`. See the [Installation Guide]({% link installation.md %}) for details.

```ruby
# config/initializers/ruby_llm.rb
RubyLLM.configure do |config|
  config.openai_api_key = ENV['OPENAI_API_KEY']
  # Add other provider configurations as needed
  config.anthropic_api_key = ENV['ANTHROPIC_API_KEY']
  config.gemini_api_key = ENV['GEMINI_API_KEY']
  # ...
end
```

### Set Up Models with `acts_as` Helpers

Include the RubyLLM helpers in your ActiveRecord models:

```ruby
# app/models/chat.rb
class Chat < ApplicationRecord
  # Includes methods like ask, with_tool, with_instructions, etc.
  # Automatically persists associated messages and tool calls.
  acts_as_chat # Assumes Message and ToolCall model names

  # --- Add your standard Rails model logic below ---
  belongs_to :user, optional: true # Example
  validates :model_id, presence: true # Example
end

# app/models/message.rb
class Message < ApplicationRecord
  # Provides methods like tool_call?, tool_result?
  acts_as_message # Assumes Chat and ToolCall model names

  # --- Add your standard Rails model logic below ---
  # Note: Do NOT add "validates :content, presence: true"
  # This would break the assistant message flow described above

  # These validations are fine:
  validates :role, presence: true
  validates :chat, presence: true
end

# app/models/tool_call.rb (Only if using tools)
class ToolCall < ApplicationRecord
  # Sets up associations to the calling message and the result message.
  acts_as_tool_call # Assumes Message model name

  # --- Add your standard Rails model logic below ---
end
```

## Basic Usage

Once your models are set up, the `acts_as_chat` helper delegates common `RubyLLM::Chat` methods to your `Chat` model:

```ruby
# Create a new chat record
chat_record = Chat.create!(model_id: 'gpt-4.1-nano', user: current_user)

# Ask a question - the persistence flow runs automatically
begin
  # This saves the user message, then calls complete() which:
  # 1. Creates an empty assistant message
  # 2. Makes the API call
  # 3. Updates the message on success, or destroys it on failure
  response = chat_record.ask "What is the capital of France?"

  # Get the persisted message record from the database
  assistant_message_record = chat_record.messages.last
  puts assistant_message_record.content # => "The capital of France is Paris."
rescue RubyLLM::Error => e
  puts "API Call Failed: #{e.message}"
  # The empty assistant message is automatically cleaned up on failure
end

# Continue the conversation
chat_record.ask "Tell me more about that city"

# Verify persistence
puts "Conversation length: #{chat_record.messages.count}" # => 4
```

### System Instructions

Instructions (system prompts) set via `with_instructions` are also automatically persisted as `Message` records with the `system` role:

```ruby
chat_record = Chat.create!(model_id: 'gpt-4.1-nano')

# This creates and saves a Message record with role: :system
chat_record.with_instructions("You are a Ruby expert.")

# Replace all system messages with a new one
chat_record.with_instructions("You are a concise Ruby expert.", replace: true)

system_message = chat_record.messages.find_by(role: :system)
puts system_message.content # => "You are a concise Ruby expert."
```

### Tools Integration

If you're using [Tools]({% link guides/tools.md %}), they're automatically persisted too:

```ruby
# Define a tool
class Weather < RubyLLM::Tool
  description "Gets current weather for a location"
  param :city, desc: "City name"

  def execute(city:)
    "The weather in #{city} is sunny and 22°C."
  end
end

# Use tools with your persisted chat
chat_record = Chat.create!(model_id: 'gpt-4.1-nano')
chat_record.with_tool(Weather)
response = chat_record.ask("What's the weather in Paris?")

# The tool call and its result are persisted
puts chat_record.messages.count # => 3 (user, assistant's tool call, tool result)
```

### Working with Attachments

If you've set up ActiveStorage as described above, you can easily send attachments to AI models with automatic type detection:

```ruby
# Create a chat
chat_record = Chat.create!(model_id: 'claude-3-5-sonnet')

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
chat_record.ask("What's in this document?", with: user.profile_document)
```

The attachment API automatically detects file types based on file extension or content type, so you don't need to specify whether something is an image, audio file, PDF, or text document - RubyLLM figures it out for you!

## Handling Persistence Edge Cases

### Orphaned Empty Messages

While the error-handling logic destroys empty assistant messages when API calls fail, there might be situations where empty messages remain (e.g., server crashes, connection drops). You can clean these up with:

```ruby
# Delete any empty assistant messages
Message.where(role: "assistant", content: "").destroy_all
```

### Providers with Empty Content Restrictions

Some providers (like Gemini) reject conversations with empty message content. If you're using these providers, ensure you've cleaned up any empty messages in your database before making API calls.

## Alternative: Validation-First Approach

If your application requires content validations or you prefer a different persistence flow, you can override the default methods to use a "validate-first" approach:

```ruby
# app/models/chat.rb
class Chat < ApplicationRecord
  acts_as_chat

  # Override the default persistence methods
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
      model_id: message.model_id,
      input_tokens: message.input_tokens,
      output_tokens: message.output_tokens
    )

    @message.save!

    # Handle tool calls if present
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

With this approach:
1. The assistant message is only created and saved after receiving a valid API response
2. Content validations work as expected
3. The trade-off is that you lose the ability to target the assistant message DOM element for streaming updates before the API call completes

## Streaming Responses with Hotwire/Turbo

The default persistence flow is designed to work seamlessly with streaming and Turbo Streams for real-time UI updates. Here's a simplified approach using a background job:

```ruby
# app/models/chat.rb
class Chat < ApplicationRecord
  acts_as_chat
  broadcasts_to ->(chat) { [chat, "messages"] }
end

# app/models/message.rb
class Message < ApplicationRecord
  acts_as_message
  broadcasts_to ->(message) { [message.chat, "messages"] }

  # Helper to broadcast chunks during streaming
  def broadcast_append_chunk(chunk_content)
    broadcast_append_to [ chat, "messages" ], # Target the stream
      target: dom_id(self, "content"), # Target the content div inside the message frame
      html: chunk_content # Append the raw chunk
  end
end

# app/jobs/chat_stream_job.rb
class ChatStreamJob < ApplicationJob
  queue_as :default

  def perform(chat_id, user_content)
    chat = Chat.find(chat_id)
    chat.ask(user_content) do |chunk|
      # Get the assistant message record (created before streaming starts)
      assistant_message = chat.messages.last
      if chunk.content && assistant_message
        # Append the chunk content to the message's target div
        assistant_message.broadcast_append_chunk(chunk.content)
      end
    end
    # Final assistant message is now fully persisted
  end
end
```

```erb
<%# app/views/chats/show.html.erb %>
<%= turbo_stream_from [@chat, "messages"] %>
<h1>Chat <%= @chat.id %></h1>
<div id="messages">
  <%= render @chat.messages %>
</div>
<!-- Your form to submit new messages -->
<%= form_with(url: chat_messages_path(@chat), method: :post) do |f| %>
  <%= f.text_area :content %>
  <%= f.submit "Send" %>
<% end %>

<%# app/views/messages/_message.html.erb %>
<%= turbo_frame_tag message do %>
  <div class="message <%= message.role %>">
    <strong><%= message.role.capitalize %>:</strong>
    <%# Target div for streaming content %>
    <div id="<%= dom_id(message, "content") %>" style="display: inline;">
      <%# Render initial content if not streaming, otherwise job appends here %>
      <%= message.content.present? ? simple_format(message.content) : '<span class="thinking">...</span>'.html_safe %>
    </div>
  </div>
<% end %>
```

### Controller Integration

Putting it all together in a controller:

```ruby
# app/controllers/messages_controller.rb
class MessagesController < ApplicationController
  before_action :set_chat

  def create
    message_content = params[:content]

    # Queue the background job to handle the streaming response
    ChatStreamJob.perform_later(@chat.id, message_content)

    # Immediately return success to the user
    respond_to do |format|
      format.turbo_stream { head :ok }
      format.html { redirect_to @chat }
    end
  end

  private

  def set_chat
    @chat = Chat.find(params[:chat_id])
  end
end
```

This setup allows for:
1. Real-time UI updates as the AI generates its response
2. Background processing to prevent request timeouts
3. Automatic persistence of all messages and tool calls

## Customizing Models

Your `Chat`, `Message`, and `ToolCall` models are standard ActiveRecord models. You can add any other associations, validations, scopes, callbacks, or methods as needed for your application logic. The `acts_as` helpers provide the core persistence bridge to RubyLLM without interfering with other model behavior.

Some common customizations include:

```ruby
# app/models/chat.rb
class Chat < ApplicationRecord
  acts_as_chat

  # Add typical Rails associations
  belongs_to :user
  has_many :favorites, dependent: :destroy

  # Add scopes
  scope :recent, -> { order(updated_at: :desc) }
  scope :with_responses, -> { joins(:messages).where(messages: { role: 'assistant' }).distinct }

  # Add custom methods
  def summary
    messages.last(2).map(&:content).join(' ... ')
  end

  # Add callbacks
  after_create :notify_administrators

  private

  def notify_administrators
    # Custom logic
  end
end
```

## Next Steps

*   [Chatting with AI Models]({% link guides/chat.md %})
*   [Using Tools]({% link guides/tools.md %})
*   [Streaming Responses]({% link guides/streaming.md %})
*   [Working with Models]({% link guides/models.md %})
*   [Error Handling]({% link guides/error-handling.md %})
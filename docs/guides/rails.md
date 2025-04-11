---
layout: default
title: Rails Integration
parent: Guides
nav_order: 5
permalink: /guides/rails
---

# Rails Integration

RubyLLM provides seamless integration with Rails through ActiveRecord models. This allows you to easily persist chats, messages, and tool calls in your database.

## Setup

### 1. Create Migrations

First, create the necessary tables in your database:

```ruby
# db/migrate/YYYYMMDDHHMMSS_create_chats.rb
class CreateChats < ActiveRecord::Migration[8.0]
  def change
    create_table :chats do |t|
      t.string :model_id
      t.timestamps
    end
  end
end

# db/migrate/YYYYMMDDHHMMSS_create_messages.rb
class CreateMessages < ActiveRecord::Migration[8.0]
  def change
    create_table :messages do |t|
      t.references :chat, null: false, foreign_key: true
      t.string :role
      t.text :content
      t.string :model_id
      t.integer :input_tokens
      t.integer :output_tokens
      t.references :tool_call
      t.timestamps
    end
  end
end

# db/migrate/YYYYMMDDHHMMSS_create_tool_calls.rb
class CreateToolCalls < ActiveRecord::Migration[8.0]
  def change
    create_table :tool_calls do |t|
      t.references :message, null: false, foreign_key: true
      t.string :tool_call_id, null: false
      t.string :name, null: false
      t.jsonb :arguments, default: {}
      t.timestamps
    end

    add_index :tool_calls, :tool_call_id
  end
end
```

Run the migrations:

```bash
rails db:migrate
```

### 2. Set Up Models

Create the model classes:

```ruby
# app/models/chat.rb
class Chat < ApplicationRecord
  acts_as_chat
end

# app/models/message.rb
class Message < ApplicationRecord
  acts_as_message
end

# app/models/tool_call.rb
class ToolCall < ApplicationRecord
  acts_as_tool_call
end
```

### 3. Configure RubyLLM

In an initializer (e.g., `config/initializers/ruby_llm.rb`):

```ruby
RubyLLM.configure do |config|
  config.openai_api_key = ENV.fetch('OPENAI_API_KEY', nil)
  config.anthropic_api_key = ENV.fetch('ANTHROPIC_API_KEY', nil)
  config.gemini_api_key = ENV.fetch('GEMINI_API_KEY', nil)
  config.deepseek_api_key = ENV.fetch('DEEPSEEK_API_KEY', nil)

  # Bedrock
  config.bedrock_api_key = ENV.fetch('AWS_ACCESS_KEY_ID', nil)
  config.bedrock_secret_key = ENV.fetch('AWS_SECRET_ACCESS_KEY', nil)
  config.bedrock_region = ENV.fetch('AWS_REGION', nil)
  config.bedrock_session_token = ENV.fetch('AWS_SESSION_TOKEN', nil)
end
```

## Basic Usage

Once your models are set up, you can use them like any other Rails model:

```ruby
# Create a new chat
chat = Chat.create!(model_id: 'gpt-4o-mini')

# Ask a question
chat.ask "What's the capital of France?"

# The response is automatically persisted
puts chat.messages.last.content

# Continue the conversation
chat.ask "Tell me more about that city"

# All messages are stored in the database
chat.messages.order(:created_at).each do |message|
  puts "#{message.role}: #{message.content}"
end
```

## Instructions (aka System Prompts)

Instructions help guide the AI's behavior throughout a conversation. With Rails integration, these messages are automatically persisted just like regular chat messages:

```ruby
# Create a new chat
chat = Chat.create!(model_id: 'gpt-4o-mini')

# Add instructions (these are persisted)
chat.with_instructions("You are a helpful Ruby programming assistant. Always include code examples in your responses and explain them line by line.")

# Ask questions - the AI will follow the instructions
response = chat.ask("How do I handle file operations in Ruby?")
puts response.content  # Will include detailed code examples

# Add additional instructions
chat.with_instructions("Always format your code using proper Ruby style conventions and include comments.")
# Both instructions are now persisted and active

# Check your system prompts
system_messages = chat.messages.where(role: 'system')
system_messages.each do |msg|
  puts "Instruction: #{msg.content}"
end
```

### When to Use Instructions

Instructions are great for:
1. Setting the AI's persona or tone
2. Providing domain-specific knowledge
3. Enforcing specific response formats
4. Creating specialized assistants

### Managing Instructions

You can add multiple instructions or replace existing ones:

```ruby
# Add initial instructions
chat.with_instructions("Be a helpful Ruby expert")

# Add another instruction (keeps the first one)
chat.with_instructions("Always include code examples")

# Replace all previous instructions
chat.with_instructions("Be a concise Ruby expert who always shows examples", replace: true)
```

This is particularly useful in controllers:

```ruby
def update_instructions
  @chat = Chat.find(params[:id])

  # Replace existing instructions with new ones
  @chat.with_instructions(params[:instructions], replace: true)

  respond_to do |format|
    format.html { redirect_to @chat }
    format.turbo_stream
  end
end
```

## Streaming Responses

You can stream responses while still persisting the final result:

```ruby
chat = Chat.create!(model_id: 'gpt-4o-mini')

chat.ask "Write a short poem about Ruby" do |chunk|
  # Stream content to the user
  ActionCable.server.broadcast "chat_#{chat.id}", { content: chunk.content }
end

# The complete message is saved in the database
puts chat.messages.last.content
```

## Using with Hotwire

RubyLLM's Rails integration works seamlessly with Hotwire for real-time updates:

```ruby
# app/models/chat.rb
class Chat < ApplicationRecord
  acts_as_chat

  # Add broadcast capabilities
  broadcasts_to ->(chat) { "chat_#{chat.id}" }
end
```

In your controller:

```ruby
# app/controllers/chats_controller.rb
class ChatsController < ApplicationController
  def show
    @chat = Chat.find(params[:id])
  end

  def ask
    @chat = Chat.find(params[:id])

    # Use a background job to avoid blocking
    ChatJob.perform_later(@chat.id, params[:message])

    # Let the user know we're working on it
    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to @chat }
    end
  end
end
```

Create a background job:

```ruby
# app/jobs/chat_job.rb
class ChatJob < ApplicationJob
  queue_as :default

  def perform(chat_id, message)
    chat = Chat.find(chat_id)

    # Start with a "typing" indicator
    Turbo::StreamsChannel.broadcast_append_to(
      chat,
      target: "messages",
      partial: "messages/typing"
    )

    chat.ask(message) do |chunk|
      # Remove typing indicator after first chunk
      if chunk == chat.messages.last.to_llm.content[0...chunk.content.length]
        Turbo::StreamsChannel.broadcast_remove_to(
          chat,
          target: "typing"
        )
      end

      # Update the streaming message
      Turbo::StreamsChannel.broadcast_replace_to(
        chat,
        target: "assistant_message_#{chat.messages.last.id}",
        partial: "messages/message",
        locals: { message: chat.messages.last, content: chunk.content }
      )
    end
  end
end
```

In your views:

```erb
<!-- app/views/chats/show.html.erb -->
<%= turbo_stream_from @chat %>

<div id="messages">
  <%= render @chat.messages %>
</div>

<%= form_with(url: ask_chat_path(@chat), method: :post) do |f| %>
  <%= f.text_area :message %>
  <%= f.submit "Send" %>
<% end %>
```

## Using Tools

Tools work seamlessly with Rails integration:

```ruby
class Weather < RubyLLM::Tool
  description "Gets current weather for a location"
  param :location, desc: "City name or zip code"

  def execute(location:)
    # Simulate weather lookup
    "15°C and sunny in #{location}"
  end
end

# Add the tool to your chat
chat = Chat.create!(model_id: 'gpt-4o-mini')
chat.with_tool(Weather)

# Ask a question that requires calculation
chat.ask "What's the weather in Berlin?"

# Tool calls are persisted
tool_call = chat.messages.find_by(role: 'assistant').tool_calls.first
puts "Tool: #{tool_call.name}"
puts "Arguments: #{tool_call.arguments}"
```

## Customizing Models

You can customize the behavior of your models:

```ruby
class Chat < ApplicationRecord
  acts_as_chat

  # Add custom behavior
  belongs_to :user
  has_many :tags

  # Add custom scopes
  scope :recent, -> { order(created_at: :desc).limit(10) }
  scope :by_model, ->(model_id) { where(model_id: model_id) }

  # Add custom methods
  def summarize
    self.ask "Please summarize our conversation so far."
  end

  def token_count
    messages.sum { |m| (m.input_tokens || 0) + (m.output_tokens || 0) }
  end
end
```

## Message Content Customization

You can customize how message content is stored or extracted:

```ruby
class Message < ApplicationRecord
  acts_as_message

  # Override content handling
  def extract_content
    # For example, compress or expand content
    JSON.parse(content) rescue content
  end
end
```

## Advanced Integration

### User Association

Associate chats with users:

```ruby
# Migration
add_reference :chats, :user, foreign_key: true

# Model
class Chat < ApplicationRecord
  acts_as_chat
  belongs_to :user
end

# Usage
user.chats.create!(model_id: 'gpt-4o-mini').ask("Hello!")
```

### Metadata and Tagging

Add metadata to chats:

```ruby
# Migration
add_column :chats, :metadata, :jsonb, default: {}

# Model
class Chat < ApplicationRecord
  acts_as_chat
end

# Usage
chat = Chat.create!(
  model_id: 'gpt-4o-mini',
  metadata: {
    purpose: 'customer_support',
    category: 'billing',
    priority: 'high'
  }
)
```

### Scoping and Filtering

Create scopes for easier querying:

```ruby
class Chat < ApplicationRecord
  acts_as_chat

  scope :using_gpt, -> { where("model_id LIKE ?", "gpt-%") }
  scope :using_claude, -> { where("model_id LIKE ?", "claude-%") }
  scope :recent, -> { order(created_at: :desc).limit(10) }
  scope :with_high_token_count, -> {
    joins(:messages)
    .group(:id)
    .having("SUM(messages.input_tokens + messages.output_tokens) > ?", 10000)
  }
end
```

## Performance Considerations

For high-volume applications:

1. **Background Processing**: Use background jobs for AI requests
2. **Connection Pooling**: Ensure your database connection pool is sized appropriately
3. **Pagination**: Use pagination when showing chat histories
4. **Archiving**: Consider archiving old chats to maintain performance

```ruby
# Example background job
class AskAiJob < ApplicationJob
  queue_as :ai_requests

  def perform(chat_id, message)
    chat = Chat.find(chat_id)
    chat.ask(message)
  end
end

# Usage
AskAiJob.perform_later(chat.id, "Tell me about Ruby")
```

## Next Steps

Now that you've integrated RubyLLM with Rails, you might want to explore:

- [Using Tools]({% link guides/tools.md %}) to add capabilities to your chats
- [Streaming Responses]({% link guides/streaming.md %}) for a better user experience
- [Error Handling]({% link guides/error-handling.md %}) to handle AI service issues gracefully

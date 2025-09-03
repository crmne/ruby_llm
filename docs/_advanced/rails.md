---
layout: default
title: Rails Integration
nav_order: 1
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

*   How to set up ActiveRecord models for persisting chats and messages
*   How the RubyLLM persistence flow works with Rails applications
*   How to use `acts_as_chat` and `acts_as_message` with your models
*   How to persist AI model metadata in your database with `acts_as_model`
*   How to send file attachments to AI models with ActiveStorage
*   How to integrate streaming responses with Hotwire/Turbo Streams
*   How to customize the persistence behavior for validation-focused scenarios

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

### Quick Setup with Generator

The easiest way to get started is using the provided Rails generator:

```bash
rails generate ruby_llm:install
```

This generator automatically:
- Creates all required migrations (Chat, Message, ToolCall, Model tables)
- Sets up model files with `acts_as_chat`, `acts_as_message`, `acts_as_tool_call`, and `acts_as_model`
- Installs ActiveStorage for file attachments
- Adds `has_many_attached :attachments` to your Message model
- Creates a RubyLLM initializer with database model registry enabled

After running the generator:

```bash
rails db:migrate
rails ruby_llm:load_models  # Populates the models table from models.json
```

You're ready to go! The generator handles all the setup complexity for you, including configuring the DB-backed model registry.

#### Generator Options

The generator supports custom model names if needed:

```bash
# Use custom model names
rails generate ruby_llm:install --chat-model-name=Conversation --message-model-name=ChatMessage --tool-call-model-name=FunctionCall

# Skip the Model registry (uses string fields instead)
rails generate ruby_llm:install --skip-model-registry

# Skip ActiveStorage installation (no file attachment support)
rails generate ruby_llm:install --skip-active-storage
```

This is useful if you already have models with these names or prefer different naming conventions.

### Manual Setup

If you prefer to set up manually or need custom table/model names, you can create the migrations yourself:

```bash
# Generate basic models and migrations
rails g model Chat model_id:string
rails g model Message chat:references role:string content:text model_id:string input_tokens:integer output_tokens:integer tool_call:references
rails g model ToolCall message:references tool_call_id:string:index name:string arguments:jsonb
rails g model Model model_id:string name:string provider:string family:string model_created_at:datetime context_window:integer max_output_tokens:integer knowledge_cutoff:date modalities:jsonb capabilities:jsonb pricing:jsonb metadata:jsonb
```

Then adjust the migrations to match what the generator creates:

```ruby
# db/migrate/YYYYMMDDHHMMSS_create_chats.rb
class CreateChats < ActiveRecord::Migration[7.1]
  def change
    create_table :chats do |t|
      t.string :model_id
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
      t.string :model_id
      t.integer :input_tokens
      t.integer :output_tokens
      t.references :tool_call
      t.timestamps
    end
  end
end

# db/migrate/YYYYMMDDHHMMSS_create_tool_calls.rb
class CreateToolCalls < ActiveRecord::Migration[7.1]
  def change
    create_table :tool_calls do |t|
      t.references :message, null: false, foreign_key: true
      t.string :tool_call_id, null: false
      t.string :name, null: false
      # Use jsonb for PostgreSQL, json for MySQL/SQLite
      t.jsonb :arguments, default: {}
      t.timestamps
    end

    add_index :tool_calls, :tool_call_id
  end
end

# db/migrate/YYYYMMDDHHMMSS_create_models.rb
class CreateModels < ActiveRecord::Migration[7.1]
  def change
    create_table :models do |t|
      t.string :model_id, null: false
      t.string :name, null: false
      t.string :provider, null: false
      t.string :family
      t.datetime :model_created_at
      t.integer :context_window
      t.integer :max_output_tokens
      t.date :knowledge_cutoff
      # Use jsonb for PostgreSQL, json for MySQL/SQLite
      t.jsonb :modalities, default: {}
      t.jsonb :capabilities, default: []
      t.jsonb :pricing, default: {}
      t.jsonb :metadata, default: {}
      t.timestamps

      t.index [:provider, :model_id], unique: true
      t.index :provider
      t.index :family
    end
  end
end
```

Run the migrations: `rails db:migrate`

> **Database Compatibility:** The generator automatically detects your database and uses `jsonb` for PostgreSQL or `json` for MySQL/SQLite. If setting up manually, adjust the column type accordingly.
{: .note }

### ActiveStorage for Attachments

The generator automatically sets up ActiveStorage and adds `has_many_attached :attachments` to your Message model. This enables file attachments out of the box.

If you skipped ActiveStorage during generation (`--skip-active-storage`), you can add it later:

```bash
rails active_storage:install
rails db:migrate
```

Then add to your Message model:

```ruby
# app/models/message.rb
class Message < ApplicationRecord
  acts_as_message
  has_many_attached :attachments  # Required for file attachments
end
```

### Configure RubyLLM

Ensure your RubyLLM configuration (API keys, etc.) is set up, typically in `config/initializers/ruby_llm.rb`. See the [Configuration Guide]({% link _getting_started/configuration.md %}) for details.

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
  acts_as_chat # Defaults to Message and ToolCall model names

  # --- Add your standard Rails model logic below ---
  belongs_to :user, optional: true # Example
end

# app/models/message.rb
class Message < ApplicationRecord
  # Provides methods like tool_call?, tool_result?
  acts_as_message # Defaults to Chat and ToolCall model names

  # --- Add your standard Rails model logic below ---
  # Note: Do NOT add "validates :content, presence: true"
  # This would break the assistant message flow described above

  # These validations are fine:
  validates :role, presence: true
  validates :chat, presence: true
end

# app/models/tool_call.rb
class ToolCall < ApplicationRecord
  # Sets up associations to the calling message and the result message.
  acts_as_tool_call # Defaults to Message model name

  # --- Add your standard Rails model logic below ---
end

# app/models/model.rb (Stores AI model metadata) - v1.7.0+
class Model < ApplicationRecord
  # Provides model registry functionality and metadata access
  acts_as_model # Defaults to Chat association

  # --- Add your standard Rails model logic below ---
end
```

### Using Provider Overrides

With the DB-backed model registry (v1.7.0+), you can specify alternate providers:

```ruby
# Use a model through a different provider
chat = Chat.create!(
  model: '{{ site.models.anthropic_current }}',
  provider: 'bedrock'  # Use AWS Bedrock instead of Anthropic
)

# The model registry handles the routing automatically
chat.ask("Hello!")
```

### Custom Contexts and Dynamic Models
{: .d-inline-block }

Available in v1.7.0+
{: .label .label-green }

#### Using Custom Contexts

For multi-tenant applications or when you need different API keys per chat:

**With DB-backed model registry (default in v1.7.0+):**

```ruby
# Create a custom context
custom_context = RubyLLM.context do |config|
  config.openai_api_key = 'sk-customer-specific-key'
end

# Pass context when creating the chat
chat = Chat.create!(
  model: '{{ site.models.openai_standard }}',
  context: custom_context
)
```

**Legacy mode (when using `--skip-model-registry`):**

```ruby
# In legacy mode, you can set context after creation
chat = Chat.create!(model_id: 'gpt-4')
chat.with_context(custom_context)  # This method only exists in legacy mode
```

> The `context` is NOT persisted to the database. You must set it again when reloading chats:
{: .warning }

```ruby
# Later, in a different request or after restart
chat = Chat.find(chat_id)
chat.context = custom_context  # Must set this!
chat.ask("Continue our conversation")
```

For multi-tenant apps, consider using an `after_find` callback:

```ruby
class Chat < ApplicationRecord
  acts_as_chat
  belongs_to :tenant

  after_find :set_tenant_context

  private

  def set_tenant_context
    self.context = RubyLLM.context do |config|
      config.openai_api_key = tenant.openai_api_key
    end
  end
end
```

#### Dynamic Model Creation

When using models not in the registry (e.g., new OpenRouter models):

```ruby
# Create chat with a dynamic model
chat = Chat.create!(
  model: 'experimental-llm-v2',
  provider: 'openrouter',
  assume_model_exists: true  # Creates Model record automatically
)
```

> Like `context`, `assume_model_exists` is NOT persisted. Set it when needed for model changes:
{: .note }

```ruby
# When switching to another dynamic model later
chat = Chat.find(chat_id)
chat.assume_model_exists = true
chat.with_model('another-experimental-model', provider: 'openrouter')
```

## Basic Usage

Once your models are set up, the `acts_as_chat` helper delegates common `RubyLLM::Chat` methods to your `Chat` model:

```ruby
# Create a new chat record
chat_record = Chat.create!(model_id: '{{ site.models.default_chat }}', user: current_user)

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

### Database Model Registry
{: .d-inline-block }

Available in v1.7.0+
{: .label .label-green }

When using the Model registry (created by default by the generator), your chats and messages get associations to model records:

```ruby
# String automatically resolves to Model record
chat = Chat.create!(model: '{{ site.models.openai_standard }}')
chat.model # => #<Model model_id: "gpt-4o", provider: "openai">
chat.model.name # => "GPT-4"
chat.model.context_window # => 128000
chat.model.supports_vision # => true

# Populate/refresh models from models.json
rails ruby_llm:load_models

# Query based on model attributes
Chat.joins(:model).where(models: { provider: 'anthropic' })
Model.left_joins(:chats).group(:id).order('COUNT(chats.id) DESC')

# Find models with specific capabilities
Model.where(supports_functions: true)
Model.where(supports_vision: true)
```

### System Instructions

Instructions (system prompts) set via `with_instructions` are also automatically persisted as `Message` records with the `system` role:

```ruby
chat_record = Chat.create!(model_id: '{{ site.models.default_chat }}')

# This creates and saves a Message record with role: :system
chat_record.with_instructions("You are a Ruby expert.")

# Replace all system messages with a new one
chat_record.with_instructions("You are a concise Ruby expert.", replace: true)

system_message = chat_record.messages.find_by(role: :system)
puts system_message.content # => "You are a concise Ruby expert."
```

### Tools Integration

[Tools]({% link _core_features/tools.md %}) are automatically persisted too:

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
chat_record = Chat.create!(model_id: '{{ site.models.default_chat }}')
chat_record.with_tool(Weather)
response = chat_record.ask("What's the weather in Paris?")

# The tool call and its result are persisted
puts chat_record.messages.count # => 3 (user, assistant's tool call, tool result)
```

### Working with Attachments

With [ActiveStorage configured](#activestorage-setup-optional), send files to AI models:

```ruby
# Create a chat
chat_record = Chat.create!(model_id: '{{ site.models.anthropic_current }}')

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

### Structured Output with Schemas
{: .d-inline-block }


Structured output works seamlessly with Rails persistence:

```ruby
# Define a schema
class PersonSchema < RubyLLM::Schema
  string :name
  integer :age
  string :city, required: false
end

# Use with your persisted chat
chat_record = Chat.create!(model_id: '{{ site.models.default_chat }}')
response = chat_record.with_schema(PersonSchema).ask("Generate a person from Paris")

# The structured response is automatically parsed as a Hash
puts response.content # => {"name" => "Marie", "age" => 28, "city" => "Paris"}

# But it's stored as JSON in the database
message = chat_record.messages.last
puts message.content # => "{\"name\":\"Marie\",\"age\":28,\"city\":\"Paris\"}"
puts JSON.parse(message.content) # => {"name" => "Marie", "age" => 28, "city" => "Paris"}
```

You can use schemas in multi-turn conversations:

```ruby
# Start with a schema
chat_record.with_schema(PersonSchema)
person = chat_record.ask("Generate a French person")

# Remove the schema for analysis
chat_record.with_schema(nil)
analysis = chat_record.ask("What's interesting about this person?")

# All messages are persisted correctly
puts chat_record.messages.count # => 4
```

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

The default persistence flow is designed to work seamlessly with streaming and Turbo Streams for real-time UI updates.

### Basic Pattern: Instant User Messages

For a better user experience, show user messages immediately while processing AI responses in the background:

```ruby
# app/controllers/messages_controller.rb
class MessagesController < ApplicationController
  def create
    @chat = Chat.find(params[:chat_id])

    # Create and persist the user message immediately
    @chat.create_user_message(params[:content])

    # Process AI response in background
    ChatStreamJob.perform_later(@chat.id)

    respond_to do |format|
      format.turbo_stream { head :ok }
      format.html { redirect_to @chat }
    end
  end
end
```

The `create_user_message` method handles message persistence and returns the created message record. This pattern provides instant feedback to users while the AI processes their request.

### Complete Streaming Setup

Here's a full implementation with background job streaming:

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

  def perform(chat_id)
    chat = Chat.find(chat_id)

    # Process the latest user message
    chat.complete do |chunk|
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


This setup allows for:
1. Real-time UI updates as the AI generates its response
2. Background processing to prevent request timeouts
3. Automatic persistence of all messages and tool calls

### Handling Message Ordering with Action Cable

Action Cable does not guarantee message order due to its concurrent processing model. Messages are distributed to worker threads that deliver them to clients concurrently, which can cause out-of-order delivery (e.g., assistant responses appearing above user messages). Here are the recommended solutions:

#### Option 1: Client-Side Reordering with Stimulus (Recommended)

Add a Stimulus controller that maintains correct chronological order based on timestamps. This example demonstrates the concept - adapt it to your specific needs:

```javascript
// app/javascript/controllers/message_ordering_controller.js
// Note: This is an example implementation. Test thoroughly before production use.
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["message"]

  connect() {
    this.reorderMessages()
    this.observeNewMessages()
  }

  observeNewMessages() {
    // Watch for new messages being added to the DOM
    const observer = new MutationObserver((mutations) => {
      let shouldReorder = false

      mutations.forEach((mutation) => {
        mutation.addedNodes.forEach((node) => {
          if (node.nodeType === 1 && node.matches('[data-message-ordering-target="message"]')) {
            shouldReorder = true
          }
        })
      })

      if (shouldReorder) {
        // Small delay to ensure all attributes are set
        setTimeout(() => this.reorderMessages(), 10)
      }
    })

    observer.observe(this.element, { childList: true, subtree: true })
    this.observer = observer
  }

  disconnect() {
    if (this.observer) {
      this.observer.disconnect()
    }
  }

  reorderMessages() {
    const messages = Array.from(this.messageTargets)

    // Sort by timestamp (created_at)
    messages.sort((a, b) => {
      const timeA = new Date(a.dataset.createdAt).getTime()
      const timeB = new Date(b.dataset.createdAt).getTime()
      return timeA - timeB
    })

    // Reorder in DOM
    messages.forEach((message) => {
      this.element.appendChild(message)
    })
  }
}
```

Update your views to use the controller:

```erb
<%# app/views/chats/show.html.erb %>
<!-- Add the Stimulus controller to the messages container -->
<div id="messages" data-controller="message-ordering">
  <%= render @chat.messages %>
</div>

<%# app/views/messages/_message.html.erb %>
<%= turbo_frame_tag message,
    data: {
      message_ordering_target: "message",
      created_at: message.created_at.iso8601
    } do %>
  <!-- message content -->
<% end %>
```

#### Option 2: Server-Side Ordering with AnyCable

[AnyCable](https://anycable.io) provides order guarantees at the server level through "sticky concurrency" - ensuring messages from the same stream are processed by the same worker. This eliminates the need for client-side reordering code.

#### Understanding the Root Cause

As confirmed by the Action Cable maintainers, Action Cable uses a threaded executor to distribute broadcast messages, so messages are delivered to connected clients concurrently. This is by design for performance reasons.

The most reliable solution is client-side reordering with order information in the payload. For applications requiring strict ordering guarantees, consider:
- Server-sent events (SSE) for unidirectional streaming
- WebSocket libraries with ordered stream support like [Lively](https://github.com/socketry/lively/tree/main/examples/chatbot)
- AnyCable for server-side ordering guarantees

**Note**: Some users report better behavior with the async Ruby stack (Falcon + async-cable), but this doesn't guarantee ordering and shouldn't be relied upon as a solution.

## Customizing Models

Your `Chat`, `Message`, and `ToolCall` models are standard ActiveRecord models. You can add any other associations, validations, scopes, callbacks, or methods as needed for your application logic. The `acts_as` helpers provide the core persistence bridge to RubyLLM without interfering with other model behavior.

You can use custom model names by passing parameters to the `acts_as` helpers. For example, if you prefer `Conversation` over `Chat`, you could use `acts_as_chat` in your `Conversation` model and then specify `chat_class: 'Conversation'` in your `Message` model's `acts_as_message` call.

### Using Custom Model Names

If your application uses different model names, you can configure the `acts_as` helpers accordingly:

```ruby
# app/models/conversation.rb (instead of Chat)
class Conversation < ApplicationRecord
  acts_as_chat message_class: 'ChatMessage',
               tool_call_class: 'AIToolCall',
               model_class: 'AiModel',
               model_foreign_key: 'ai_model_id'

  belongs_to :user, optional: true
end

# app/models/chat_message.rb (instead of Message)
class ChatMessage < ApplicationRecord
  acts_as_message chat_class: 'Conversation',
                  chat_foreign_key: 'conversation_id',
                  tool_call_class: 'AIToolCall',
                  model_class: 'AiModel',
                  model_foreign_key: 'ai_model_id'
end

# app/models/ai_tool_call.rb (instead of ToolCall)
class AIToolCall < ApplicationRecord
  acts_as_tool_call message_class: 'ChatMessage',
                    message_foreign_key: 'chat_message_id'
end

# app/models/ai_model.rb (instead of Model)
class AiModel < ApplicationRecord
  acts_as_model chat_class: 'Conversation'
end
```

This flexibility allows you to integrate RubyLLM with existing Rails applications that may already have naming conventions established.

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

*   [Chatting with AI Models]({% link _core_features/chat.md %})
*   [Using Tools]({% link _core_features/tools.md %})
*   [Streaming Responses]({% link _core_features/streaming.md %})
*   [Working with Models]({% link _advanced/models.md %})
*   [Error Handling]({% link _advanced/error-handling.md %})

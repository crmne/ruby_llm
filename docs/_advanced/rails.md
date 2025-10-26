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
*   How to store raw provider payloads (Anthropic prompt caching, etc.)
*   How to integrate streaming responses with Hotwire/Turbo Streams
*   How to customize the persistence behavior for validation-focused scenarios

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

> **Important:** You cannot use `validates :content, presence: true` on your Message model. See [Customizing the Persistence Flow](#customizing-the-persistence-flow) for an alternative approach.
{: .warning }

## Setting Up Your Rails Application

### Quick Setup with Generator

The easiest way to get started is using the provided Rails generator:

```bash
rails generate ruby_llm:install
```

The generator:
- Creates migrations for Chat, Message, ToolCall, and Model tables
- Sets up model files with appropriate `acts_as` declarations
- Installs ActiveStorage for file attachments
- Configures the database model registry
- Creates an initializer with sensible defaults

After running the generator:

```bash
rails db:migrate
```

Your Rails app is now AI-ready!


### Adding a Chat UI

Want a ready-to-use chat interface? Run the chat UI generator:

```bash
rails generate ruby_llm:chat_ui
```

This creates a complete chat interface with:
- **Controllers**: Handles chat and message creation with background processing
- **Views**: Modern UI with Turbo Streams for real-time updates
- **Jobs**: Background job for processing AI responses without blocking
- **Routes**: RESTful routes for chats and messages

After running the generator, start your server and visit `http://localhost:3000/chats` to begin chatting!

The UI generator also supports custom model names:

```bash
# Use your custom model names from the install generator
rails generate ruby_llm:chat_ui chat:Conversation message:ChatMessage model:AIModel
```

#### Generator Options

The generator uses Rails-like syntax for custom model names:

```bash
# Default - creates Chat, Message, ToolCall, Model
rails generate ruby_llm:install

# Custom model names using Rails conventions
rails generate ruby_llm:install chat:Conversation message:ChatMessage
rails generate ruby_llm:install chat:Discussion message:DiscussionMessage tool_call:FunctionCall model:AIModel

# Skip ActiveStorage if you don't need file attachments
rails generate ruby_llm:install --skip-active-storage
```

The `name:ClassName` syntax follows Rails conventions - specify only what you want to customize.


### Setting Up ActiveStorage

The generator automatically configures ActiveStorage for file attachments. If you skipped it during generation, add it manually:

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

### Working with Raw Provider Payloads, Anthropic Prompt Caching
{: .d-inline-block }

v1.9.0+
{: .label .label-green }

Providers like Anthropic expose advanced features (prompt caching, fine-grained metadata) by embedding rich structures inside each prompt block. Use `RubyLLM::Content::Raw` to persist those blocks alongside your conversation history:

```ruby
raw_block = RubyLLM::Content::Raw.new([
  { type: 'text', text: 'Reusable analysis prompt', cache_control: { type: 'ephemeral' } },
  { type: 'text', text: "Today's request: #{summary}" }
])

chat = Chat.create!(model: 'claude-sonnet-4-5')
chat.ask(raw_block)
```

The v1.9 schema adds a `content_raw` column so raw payloads live alongside the plain-text `content` field. When you load messages via `acts_as_message`, RubyLLM reconstructs the original `Content::Raw` automatically.

> Existing apps: run `rails generate ruby_llm:upgrade_to_v1_9` to add cached-token tracking and raw content storage columns introduced in v1.9.0. New apps will get the proper columns from the install generator.
{: .note }

### Configuring RubyLLM

Set up your API keys and other configuration in the initializer:

```ruby
# config/initializers/ruby_llm.rb
RubyLLM.configure do |config|
  config.openai_api_key = ENV['OPENAI_API_KEY']
  config.anthropic_api_key = ENV['ANTHROPIC_API_KEY']
  config.gemini_api_key = ENV['GEMINI_API_KEY']

  # New apps: Use modern API (generator adds this)
  config.use_new_acts_as = true

  # For custom Model class names (defaults to 'Model')
  # config.model_registry_class = 'AIModel'
end
```

### Setting Up Models with `acts_as` Helpers

> **New in v1.7.0:** Rails-like `acts_as` API with association names!
> - **New apps**: Generator sets `config.use_new_acts_as = true` for modern API
> - **Existing apps**: Continue using legacy API (with deprecation warning)
> - **Migrate today**: Set `config.use_new_acts_as = true` to use the better API
> - **Legacy API removed in 2.0**: The new API will become the only option
{: .warning }

Add RubyLLM capabilities to your models:

#### With Model Registry (Default for new apps)
{: .d-inline-block }

Available in v1.7.0+
{: .label .label-green }

```ruby
# app/models/chat.rb
class Chat < ApplicationRecord
  # New API style - uses association names as primary parameters
  acts_as_chat # Defaults: messages: :messages, model: :model

  # Or with custom associations:
  # acts_as_chat messages: :chat_messages,
  #              message_class: 'ChatMessage',  # Only needed if class can't be inferred
  #              model: :ai_model

  belongs_to :user, optional: true
end

# app/models/message.rb
class Message < ApplicationRecord
  # New API style - uses association names
  acts_as_message # Defaults: chat: :chat, tool_calls: :tool_calls, model: :model

  # Or with custom associations:
  # acts_as_message chat: :conversation,
  #                 chat_class: 'Conversation',  # Only needed if class can't be inferred
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

#### Legacy Mode (Without Model Registry)
{: .d-inline-block }

Pre-1.7.0 or opt-in
{: .label .label-yellow }

> Default behavior for existing apps. Set `config.use_new_acts_as = true` to upgrade! Legacy API will be removed in 2.0.
{: .note }

```ruby
# app/models/chat.rb
class Chat < ApplicationRecord
  # Legacy API style - requires explicit class names
  acts_as_chat message_class: 'Message',
               tool_call_class: 'ToolCall',
               model_class: 'Model'  # Ignored in legacy mode
end

# app/models/message.rb
class Message < ApplicationRecord
  # Legacy API style - all class names and foreign keys explicit
  acts_as_message chat_class: 'Chat',
                  chat_foreign_key: 'chat_id',
                  tool_call_class: 'ToolCall',
                  model_class: 'Model'  # Ignored in legacy mode
end

# app/models/tool_call.rb
class ToolCall < ApplicationRecord
  acts_as_tool_call message_class: 'Message',
                    message_foreign_key: 'message_id'
end

# Note: No Model class in legacy mode - uses string fields instead
```

### Provider Overrides
{: .d-inline-block }

Available in v1.7.0+
{: .label .label-green }

Route models through different providers dynamically:

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

Use different API keys per chat in multi-tenant applications:

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
chat = Chat.create!(model: 'gpt-4')
chat.with_context(custom_context)  # This method only exists in legacy mode
```

> **Warning:** Context is not persisted. Set it after reloading chats.
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

> **Note:** Like context, `assume_model_exists` is not persisted.
{: .note }

```ruby
# When switching to another dynamic model later
chat = Chat.find(chat_id)
chat.assume_model_exists = true
chat.with_model('another-experimental-model', provider: 'openrouter')
```

## Working with Chats

### Basic Chat Operations

The `acts_as_chat` helper provides all standard chat methods:

```ruby
# Create a chat
chat_record = Chat.create!(model: '{{ site.models.default_chat }}', user: current_user)

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

System prompts are persisted as messages with the `system` role:

```ruby
chat_record = Chat.create!(model: '{{ site.models.default_chat }}')

# This creates and saves a Message record with role: :system
chat_record.with_instructions("You are a Ruby expert.")

# Replace all system messages with a new one
chat_record.with_instructions("You are a concise Ruby expert.", replace: true)

system_message = chat_record.messages.find_by(role: :system)
puts system_message.content # => "You are a concise Ruby expert."
```

### Using Tools

Tools are Ruby classes that the AI can call. While the tool classes themselves aren't persisted, the tool calls and their results are saved as messages:

```ruby
# Define a tool (this is just a Ruby class, not persisted)
class Weather < RubyLLM::Tool
  description "Gets current weather for a location"
  param :city, desc: "City name"

  def execute(city:)
    "The weather in #{city} is sunny and 22°C."
  end
end

# Register the tool with your chat
chat_record = Chat.create!(model: '{{ site.models.default_chat }}')
chat_record.with_tool(Weather)

# When the AI uses the tool, both the call and result are persisted
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
# Create a chat
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
chat_record.ask("What's in this document?", with: user.profile_document)
```

File types are automatically detected from extensions or MIME types.

### Structured Output

Generate and persist structured responses:

```ruby
# Define a schema
class PersonSchema < RubyLLM::Schema
  string :name
  integer :age
  string :city, required: false
end

# Use with your persisted chat
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
# Start with a schema
chat_record.with_schema(PersonSchema)
person = chat_record.ask("Generate a French person")

# Remove the schema for analysis
chat_record.with_schema(nil)
analysis = chat_record.ask("What's interesting about this person?")

# All messages are persisted correctly
puts chat_record.messages.count # => 4
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
      model: Model.find_by(model_id: message.model_id),
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

This approach trades streaming UI updates for content validation support:
- ✅ Content validations work
- ✅ No empty messages in database
- ❌ No DOM target for streaming before API response

## Streaming Responses with Hotwire/Turbo

The default persistence flow is designed to work seamlessly with streaming and Turbo Streams for real-time UI updates.

### Instant User Messages

Show user messages immediately for better UX:

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

The `create_user_message` method provides instant feedback while processing continues in the background.

### Full Streaming Implementation

Complete example with background jobs and Turbo Streams:

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


This implementation provides:
- Real-time UI updates during generation
- Background processing to prevent timeouts
- Automatic persistence of all messages and tool calls

### Message Ordering Issues

Action Cable processes messages concurrently, which can cause out-of-order delivery:

#### Solution 1: Client-Side Reordering (Recommended)

Use Stimulus to maintain chronological order:

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

#### Solution 2: Server-Side Ordering

[AnyCable](https://anycable.io) provides order guarantees at the server level through "sticky concurrency" - ensuring messages from the same stream are processed by the same worker. This eliminates the need for client-side reordering code.

#### Why This Happens

Action Cable uses concurrent processing by design for performance.

For strict ordering requirements, consider:
- Server-sent events (SSE) for unidirectional streaming
- WebSocket libraries with ordered stream support like [Lively](https://github.com/socketry/lively/tree/main/examples/chatbot)
- AnyCable for server-side ordering guarantees

> **Note:** The async Ruby stack (Falcon + async-cable) may improve behavior but doesn't guarantee ordering.
{: .note }

## Customizing Models

The `acts_as` helpers integrate seamlessly with standard Rails patterns. Add associations, validations, scopes, and callbacks as needed.

### Using Custom Model Names

If your application uses different model names, you can configure the `acts_as` helpers accordingly:

#### With Model Registry
{: .d-inline-block }

Available in v1.7.0+
{: .label .label-green }

```ruby
# app/models/conversation.rb (instead of Chat)
class Conversation < ApplicationRecord
  acts_as_chat messages: :chat_messages,  # Association name
               message_class: 'ChatMessage',  # Optional if inferrable
               model: :ai_model,
               model_class: 'AiModel'  # Optional if inferrable

  belongs_to :user, optional: true
end

# app/models/chat_message.rb (instead of Message)
class ChatMessage < ApplicationRecord
  acts_as_message chat: :conversation,  # Association name
                  chat_class: 'Conversation',  # Optional if inferrable
                  tool_calls: :ai_tool_calls,
                  tool_call_class: 'AIToolCall',  # Required for non-standard naming
                  model: :ai_model
end

# app/models/ai_tool_call.rb (instead of ToolCall)
class AIToolCall < ApplicationRecord
  acts_as_tool_call message: :chat_message,
                    message_class: 'ChatMessage',  # Optional if inferrable
                    result: :result
end

# app/models/ai_model.rb (instead of Model)
class AiModel < ApplicationRecord
  acts_as_model chats: :conversations,
                chat_class: 'Conversation'  # Optional if inferrable
end
```

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
                    chat_class: 'Admin::BotChat'  # Required for namespace
  end
end
```

#### Legacy Mode
{: .d-inline-block }

Pre-1.7.0 or opt-in
{: .label .label-yellow }

```ruby
# app/models/conversation.rb
class Conversation < ApplicationRecord
  acts_as_chat message_class: 'ChatMessage',
               tool_call_class: 'AIToolCall'
end

# app/models/chat_message.rb
class ChatMessage < ApplicationRecord
  acts_as_message chat_class: 'Conversation',
                  chat_foreign_key: 'conversation_id',
                  tool_call_class: 'AIToolCall'
end

# app/models/ai_tool_call.rb
class AIToolCall < ApplicationRecord
  acts_as_tool_call message_class: 'ChatMessage',
                    message_foreign_key: 'chat_message_id'
end
```

### Common Customizations

Extend your models with standard Rails patterns:

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

---
layout: default
title: Streaming with Hotwire/Turbo
parent: "Rails Integration"
nav_order: 2
description: Broadcast AI responses token by token to the browser with Turbo Streams and background jobs.
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

*   How to show user messages instantly while the AI responds in the background.
*   How to stream assistant responses to the browser with Turbo Streams.
*   How to wire a background job to `complete` and broadcast each chunk.
*   How to handle out-of-order message delivery from Action Cable.

The default persistence flow is built for real-time UIs. Because RubyLLM creates the assistant message on the first streamed chunk, you get a stable DOM target to append tokens into. This guide assembles a controller, a model, a background job, and views into a complete streaming chat, then covers the ordering quirks of Action Cable.

## Streaming Responses with Hotwire/Turbo

The default persistence flow is designed to work seamlessly with streaming and Turbo Streams for real-time UI updates.

### Instant User Messages

Show user messages immediately for better UX:

```ruby
# app/controllers/messages_controller.rb
class MessagesController < ApplicationController
  def create
    @chat = Chat.find(params[:chat_id])

    @chat.add_message(role: :user, content: params[:content])

    ChatStreamJob.perform_later(@chat.id)

    respond_to do |format|
      format.turbo_stream { head :ok }
      format.html { redirect_to @chat }
    end
  end
end
```

The `add_message` method provides instant feedback while processing continues in the background.

### Full Streaming Implementation

Complete example with background jobs and Turbo Streams:

```ruby
# app/models/chat.rb
class Chat < ApplicationRecord
  acts_as_chat
end

# app/models/message.rb
class Message < ApplicationRecord
  acts_as_message
  broadcasts_to ->(message) { "chat_#{message.chat_id}" }

  def broadcast_append_chunk(chunk_content)
    broadcast_append_to "chat_#{chat_id}",
      target: "message_#{id}_content",
      partial: "messages/content",
      locals: { content: chunk_content }
  end
end

# app/jobs/chat_stream_job.rb
class ChatStreamJob < ApplicationJob
  queue_as :default

  def perform(chat_id)
    chat = Chat.find(chat_id)

    chat.complete do |chunk|
      # Get the assistant message record (created before streaming starts)
      assistant_message = chat.messages.last
      if chunk.content && assistant_message
        assistant_message.broadcast_append_chunk(chunk.content)
      end
    end
  end
end
```

```erb
<%# app/views/chats/show.html.erb %>
<%= turbo_stream_from "chat_#{@chat.id}" %>
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
<div id="message_<%= message.id %>" class="message">
  <strong><%= message.role.capitalize %>:</strong>
  <div id="message_<%= message.id %>_content" style="white-space: pre-wrap;">
    <%= message.content %>
  </div>
</div>
```

This helper intentionally lives in your app model (via generator) rather than core RubyLLM methods, so streaming behavior stays explicit and customizable.

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

The async Ruby stack (Falcon + async-cable) may improve behavior but doesn't guarantee ordering.
{: .note }

## Next Steps

*   [Generators and App Conventions]({% link _advanced/rails-generators.md %}) - generate a ready-made streaming chat UI with one command.
*   [Persistence with acts_as]({% link _advanced/rails-persistence.md %}) - the persistence flow that makes streaming targets possible.
*   [Streaming]({% link _core_features/streaming.md %}) - the underlying streaming API and chunk format.
*   [Scale with Async]({% link _advanced/async.md %}) - run concurrent streams without blocking threads.

---
layout: default
title: Streaming with Hotwire/Turbo
parent: "Rails Integration"
nav_order: 2
description: Broadcast AI responses token by token to the browser with Turbo Streams and background jobs.
---

# {{ page.title }}

{{ page.description }}
{: .fs-6 .fw-300 }

After reading this guide, you will know:

*   How to show user messages instantly while the AI responds in the background.
*   How to stream assistant responses to the browser with Turbo Streams.
*   How to wire a background job to `complete` and broadcast each chunk.
*   How to handle out-of-order message delivery from Action Cable.

The default persistence flow is built for real-time UIs. Because RubyLLM creates the assistant message before streaming starts, you get a stable DOM target to append tokens into. This guide assembles a controller, a model, a background job, and views into a complete streaming chat, then covers the ordering quirks of Action Cable.

## Instant User Messages

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

## Full Streaming Implementation

`acts_as_message` broadcasts with Turbo when turbo-rails and Action Cable are loaded, so a streaming chat needs a job and a view:

```ruby
# app/models/chat.rb
class Chat < ApplicationRecord
  acts_as_chat
end

# app/models/message.rb
class Message < ApplicationRecord
  acts_as_message
end

# app/jobs/chat_stream_job.rb
class ChatStreamJob < ApplicationJob
  def perform(chat_id)
    Chat.find(chat_id).complete(&:broadcast)
  end
end
```

Each chunk a persisted chat streams knows its record: `chunk.message` is the assistant message it belongs to, and `chunk.broadcast` appends it to that message on the page. When the run ends, the chat's page refreshes.

```erb
<%# app/views/chats/show.html.erb %>
<% turbo_refreshes_with method: :morph, scroll: :preserve %>
<%= turbo_stream_from @chat %>
<div id="messages">
  <%= render @chat.messages %>
</div>

<%# app/views/messages/_assistant.html.erb %>
<div id="<%= dom_id(assistant) %>">
  <div id="<%= dom_id(assistant) %>_stream"><%= assistant.content %></div>
</div>
```

The message broadcasts to the chat record's stream, so the view subscribes with `turbo_stream_from @chat`. Rails renders each message with its partial, chosen by `to_partial_path`: `messages/_user`, `messages/_assistant`, `messages/_tool`, and `messages/_tool_calls`. The [chat UI generator]({% link _advanced/rails-generators.md %}#adding-a-chat-ui) writes all of them.

If your application broadcasts its messages itself, turn RubyLLM's broadcasting off so nothing is sent twice:

```ruby
class Message < ApplicationRecord
  acts_as_message broadcasts: false
end
```

## Cancelling a Background Stream

`acts_as_chat` stores cancellation requests on the chat record. A stop button can call `cancel` from the web process while the background job is streaming. The job observes the request, clears it, and raises `RubyLLM::CancelledError`.

```ruby
# app/controllers/chats_controller.rb
class ChatsController < ApplicationController
  def cancel
    Chat.find(params[:id]).cancel
    head :no_content
  end
end

# app/jobs/chat_stream_job.rb
class ChatStreamJob < ApplicationJob
  def perform(chat_id)
    chat = Chat.find(chat_id)

    chat.complete(&:broadcast)
  rescue RubyLLM::CancelledError
    # Broadcast cancelled UI state if your app needs it.
  end
end
```

## Message Ordering Issues

Action Cable processes messages concurrently, which can cause out-of-order delivery:

#### Solution 1: Numbered Chunks and Page Refreshes

This is what `acts_as_message` and the [generated chat UI]({% link _advanced/rails-generators.md %}#adding-a-chat-ui) do. Each chunk is sent once, as a span numbered with `chunk.index` that also names the chunk before it:

```html
<span data-seq="7" data-after="5">Hello</span>
```

A small Stimulus controller, `app/javascript/controllers/chat_message_controller.js`, keeps the spans in a hidden source element, puts them in order, drops repeats, and shows the text up to the first missing chunk. It renders that text as Markdown with [marked](https://marked.js.org) and sanitizes the result with [DOMPurify](https://github.com/cure53/DOMPurify), at most once per animation frame. It shows images and raw HTML as text, because an image the model was tricked into writing would send chat data to its URL without a click; files the chat returns still appear as attachments.

Every other change, such as a new message or an approval card, broadcasts a page refresh. A refresh fetches the chat again and morphs the page into it, so the order refreshes arrive in cannot matter. The empty assistant message is appended as soon as it is created, so it is on the page before its first chunk. When the reply is saved, the message replaces itself once with the full text. The finished message has no `_stream` element, so a chunk that arrives after the replace finds no target and Turbo drops it. The controller also keeps a refresh from emptying a reply that is still streaming, and keeps a late placeholder from replacing a finished one. Without JavaScript, the page shows the source as plain text.

Morphing needs `<%= yield :head %>` in your layout. The chat UI generator adds it when your layout lacks it.

#### Solution 2: Client-Side Reordering

Use Stimulus to maintain chronological order:

```javascript
// app/javascript/controllers/message_ordering_controller.js
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

#### Solution 3: Server-Side Ordering

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

---
layout: default
title: Chat
nav_order: 1
has_children: true
description: Learn how to have conversations with AI models, work with different providers, and attach files like images and PDFs
redirect_from:
  - /guides/chat
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

* How to start and continue conversations with AI models.
* How to guide AI behavior with system prompts.
* How to select and work with different models and providers.
* How to control response creativity with temperature.
* How to read the raw provider response.
* Where to go for file attachments, request control, token tracking, and event handlers.

## Starting a Conversation

When you want to interact with an AI model, you create a chat instance. The simplest approach uses `RubyLLM.chat`, which creates a new conversation with your configured default model.

```ruby
chat = RubyLLM.chat

response = chat.ask "Explain the concept of 'Convention over Configuration' in Rails."

puts response.content
# => "Convention over Configuration (CoC) is a core principle of Ruby on Rails..."

puts "Model Used: #{response.model_id}"
puts "Tokens Used: #{response.tokens.input} input, #{response.tokens.output} output"
puts "Cache Reads: #{response.tokens.cache_read}" # v1.15+
puts "Cache Writes: #{response.tokens.cache_write}" # v1.15+
```

The `ask` method adds your message to the conversation history with the `:user` role, sends the entire conversation history to the AI provider, and returns a `RubyLLM::Message` object containing the assistant's response.

The `say` method is an alias for `ask`, so you can use whichever feels more natural in your code.

When the model uses [tools]({% link _core_features/tools.md %}), `ask` runs the conversation to completion: it calls the model, runs any tools the model asks for, and calls the model again until it answers without a tool. When you need to control that loop yourself, see [Driving the Loop Yourself]({% link _advanced/agentic-workflows.md %}#driving-the-loop-yourself).

## Continuing the Conversation

One of the key features of chat-based AI models is their ability to maintain context across multiple exchanges. The `Chat` object automatically manages this conversation history for you.

```ruby
response = chat.ask "Can you give a specific example in Rails?"
puts response.content
# => "Certainly! A classic example is database table naming..."

chat.messages.each do |message|
  puts "[#{message.role.to_s.upcase}] #{message.content.lines.first.strip}"
end
# => [USER] Explain the concept of 'Convention over Configuration' in Rails.
# => [ASSISTANT] Convention over Configuration (CoC) is a core principle...
# => [USER] Can you give a specific example in Rails?
# => [ASSISTANT] Certainly! A classic example is database table naming...
```

Each time you call `ask`, RubyLLM sends the entire conversation history to the AI provider. This allows the model to understand the full context of your conversation, enabling natural follow-up questions and maintaining coherent dialogue.

## Guiding AI Behavior with System Prompts

System prompts, also called instructions, allow you to set the overall behavior, personality, and constraints for the AI assistant. These instructions persist throughout the conversation and help ensure consistent responses.

```ruby
chat = RubyLLM.chat

chat.with_instructions "You are a helpful assistant that explains Ruby concepts simply, like explaining to a five-year-old."

response = chat.ask "What is a variable?"
puts response.content
# => "Imagine you have a special box, and you can put things in it..."

# By default, with_instructions replaces the active system instruction
chat.with_instructions "Always end your response with 'Got it?'"

response = chat.ask "What is a loop?"
puts response.content
# => "A loop is like singing your favorite song over and over again... Got it?"

# Append an additional system instruction only when needed
chat.with_instructions "Use exactly one short paragraph.", append: true
```

System prompts are added to the conversation as messages with the `:system` role and are sent with every request to the AI provider. This ensures the model always considers your instructions when generating responses.

When using the [Rails Integration]({% link _advanced/rails.md %}), system messages are persisted in your database along with user and assistant messages, maintaining the full conversation context.
{: .note }

## Working with Different Models

RubyLLM supports over 600 models from various providers. While `RubyLLM.chat` uses your configured default model, you can specify different models:

```ruby
chat_claude = RubyLLM.chat(model: '{{ site.models.anthropic_current }}')
chat_gemini = RubyLLM.chat(model: '{{ site.models.gemini_current_latest }}')

chat = RubyLLM.chat(model: '{{ site.models.default_chat }}')
response1 = chat.ask "Initial question..."

chat.with_model('{{ site.models.anthropic_latest }}')
response2 = chat.ask "Follow-up question..."
```

For detailed information about model selection, capabilities, aliases, and working with custom models, see [Working with Models]({% link _reference/models.md %}). For exactly how a name becomes a model and provider, see [Model Resolution]({% link _reference/model-resolution.md %}).

## Controlling Responses

### Temperature and Creativity

The temperature parameter controls the randomness of the model's responses. Understanding temperature helps you get the right balance between creativity and consistency for your use case.

* **Low temperature (0.0 - 0.3)**: More deterministic and focused responses. Use for factual queries, technical explanations, or when consistency is important.
* **Medium temperature (0.4 - 0.7)**: Balanced creativity and coherence. Good for general conversation and most applications.
* **High temperature (0.8 - 1.0)**: More creative and varied responses. Use for brainstorming, creative writing, or when you want diverse outputs.

```ruby
factual_chat = RubyLLM.chat.with_temperature(0.2)
response1 = factual_chat.ask "What is the boiling point of water at sea level in Celsius?"
puts response1.content

creative_chat = RubyLLM.chat.with_temperature(0.9)
response2 = creative_chat.ask "Write a short poem about the color blue."
puts response2.content
```

The `with_temperature` method returns the chat instance, allowing you to chain multiple configuration calls together.

For provider-specific request options, wire protocols, raw content blocks, and custom HTTP headers, see [Advanced Request Control]({% link _core_features/chat-request-control.md %}).

## Raw Responses

You can access the raw response from the API provider with `response.raw`.

```ruby
response = chat.ask("What is the capital of France?")
puts response.raw.body
```

The raw response is a `Faraday::Response` object, which you can use to access the headers, body, and status code.

## Advanced: Replacing the LLM Transcript

For advanced context management, `chat.messages` is whatever you show the LLM. Your application can keep and render a different user-visible transcript if needed. This is useful for chat compaction, moderation, redaction, or any workflow where the LLM should see a different transcript from the user.

```ruby
messages_for_model = chat.messages.last(4)
chat.messages = messages_for_model
```

For persisted Rails chats, see [Separate User and LLM Transcripts]({% link _advanced/rails-persistence.md %}#separate-user-and-llm-transcripts).

## Going Further

This page covers the core `Chat` interface. Each facet of a conversation has its own focused guide:

* [Attachments]({% link _core_features/attachments.md %}) - attach images, video, audio, text files, and PDFs to a message.
* [Streaming]({% link _core_features/streaming.md %}) - display responses in real time as they are generated.
* [Structured Output]({% link _core_features/structured-output.md %}) - get responses that match an exact JSON schema.
* [Extended Thinking]({% link _core_features/thinking.md %}) - give reasoning models room to deliberate and read their thinking.
* [Citations]({% link _core_features/citations.md %}) - get verifiable answers backed by your documents and web sources.
* [Advanced Request Control]({% link _core_features/chat-request-control.md %}) - provider-specific parameters, wire protocols, raw content blocks, and custom headers.
* [Token Usage and Cost]({% link _core_features/chat-tokens.md %}) - read per-turn and per-conversation token counts and costs.
* [Chat Event Handlers]({% link _core_features/chat-callbacks.md %}) - hook into the chat lifecycle for UI updates, logging, and analytics.

## Next Steps

* [Using Tools]({% link _core_features/tools.md %}) - enable the AI to call your Ruby code.
* [Working with Models]({% link _reference/models.md %}) - choose the best model and handle custom endpoints.
* [Rails Integration]({% link _advanced/rails.md %}) - persist your chat conversations easily.
* [Error Handling]({% link _advanced/error-handling.md %}) - build robust applications that handle API issues.

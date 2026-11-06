---
layout: default
title: Official Ruby SDKs
seo:
  title: RubyLLM and the Official SDKs
nav_order: 7
description: Compare RubyLLM with the official openai and anthropic gems on requests, streaming, the tool loop, structured output, Rails, and cost.
permalink: /compare/official-sdks/
---

# RubyLLM and the Official SDKs

{{ page.description }}
{: .fs-6 .fw-300 }

After reading this guide, you will know:

* What the official SDKs are built for, and what RubyLLM is built for.
* How a request, a stream, a tool, and a schema look in each.
* What each one leaves to your application: the loop, persistence, and cost.
* How RubyLLM reaches a parameter a vendor shipped this morning.
* When to choose an official SDK, and when to use both.

> **Last checked** on 5 November 2026 against RubyLLM 2.2, the [`openai`](https://rubygems.org/gems/openai) gem 0.119.0 (released 5 November 2026), and the [`anthropic`](https://rubygems.org/gems/anthropic) gem 2.5.0 (released 4 November 2026). The SDK code comes from the [openai-ruby README](https://github.com/openai/openai-ruby#readme) and Anthropic's [Ruby SDK documentation](https://platform.claude.com/docs/en/api/sdks/ruby). Model names match the RubyLLM examples, and comments were removed.

## One Vendor or One API

The `openai` and `anthropic` gems are generated from each vendor's API specification. Every endpoint and every parameter is there on the day it ships, with typed request and response models. Each gem speaks to one vendor.

RubyLLM is a framework on top of the providers. It gives the same calls to OpenAI, Anthropic, Gemini, Bedrock, and the other [providers]({% link _reference/configuration-providers.md %}), runs the agent loop, stores conversations in Rails, and prices responses from its model registry.

## A Request

With the official SDKs, you build a client and send the vendor's request shape. Anthropic requires `max_tokens` and returns a list of content blocks:

```ruby
anthropic = Anthropic::Client.new

message = anthropic.messages.create(
  max_tokens: 1024,
  messages: [{role: "user", content: "Hello, Claude"}],
  model: "{{ site.models.anthropic_opus }}"
)

message.content.each do |block|
  puts block.text if block.type == :text
end
```

OpenAI's Responses API has its own shape:

```ruby
openai = OpenAI::Client.new

response = openai.responses.create(
  model: "{{ site.models.openai_latest }}",
  input: "Say hello!"
)

puts(response.output_text)
```

In RubyLLM, the provider is a model name:

```ruby
RubyLLM.chat(model: "{{ site.models.anthropic_opus }}").ask "Hello, Claude"
RubyLLM.chat(model: "{{ site.models.openai_latest }}").ask "Say hello!"
```

Both return a `RubyLLM::Message` with `content`, `tokens`, and `cost`. The chat keeps the transcript, so a second `ask` continues the conversation instead of starting a new request body.

## Streaming

Anthropic's stream has a text helper:

```ruby
stream = anthropic.messages.stream(
  max_tokens: 1024,
  messages: [{role: :user, content: "Say hello there!"}],
  model: "{{ site.models.anthropic_opus }}"
)

stream.text.each do |text|
  print(text)
end
```

RubyLLM streams through a block, for every provider:

```ruby
chat = RubyLLM.chat model: "{{ site.models.anthropic_opus }}"

chat.ask "Say hello there!" do |chunk|
  print chunk.content
end
```

`ask` still returns the complete message after the last chunk, so you never assemble a stream to keep the answer.

## The Agent Loop

Both SDKs now ship a tool runner. Anthropic's runs tools declared as `Anthropic::BaseTool` classes, in its beta namespace:

```ruby
class CalculatorInput < Anthropic::BaseModel
  required :lhs, Float
  required :rhs, Float
  required :operator, Anthropic::InputSchema::EnumOf[:+, :-, :*, :/]
end

class Calculator < Anthropic::BaseTool
  input_schema CalculatorInput

  def call(expr)
    expr.lhs.public_send(expr.operator, expr.rhs)
  end
end

anthropic.beta.messages.tool_runner(
  model: "{{ site.models.anthropic_opus }}",
  max_tokens: 1024,
  messages: [{role: "user", content: "What's 15 * 7?"}],
  tools: [Calculator.new]
).each_message { |message| puts message.content }
```

OpenAI's `run_tools` covers Chat Completions. Its README notes that it does not stream, runs callbacks one after another, and supports function tools only. With the Responses API, you write the loop yourself.

In RubyLLM, the loop is what `ask` does:

```ruby
class Calculator < RubyLLM::Tool
  description "Does arithmetic on two numbers"

  parameters do
    number :lhs
    number :rhs
    string :operator, enum: %w[+ - * /]
  end

  def execute(lhs:, rhs:, operator:) = lhs.to_f.public_send(operator, rhs)
end

chat = RubyLLM.chat(model: "{{ site.models.anthropic_opus }}").with_tools Calculator
chat.ask "What's 15 * 7?"
```

The same loop streams, runs tools concurrently when you ask it to, pauses a call for [human approval]({% link _tools/tool-execution.md %}), takes messages queued while it runs, and works on every provider. With Rails persistence, it resumes in another process. See [Tools]({% link _getting_started/tools.md %}) and [Agentic Workflows]({% link _advanced/agentic-workflows.md %}).

## Structured Output

openai-ruby turns an `OpenAI::BaseModel` into a schema and parses the response into it:

```ruby
class Participant < OpenAI::BaseModel
  required :first_name, String
  required :last_name, String, nil?: true
  required :status, OpenAI::EnumOf[:confirmed, :unconfirmed, :tentative]
end

class CalendarEvent < OpenAI::BaseModel
  required :name, String
  required :date, String
  required :participants, OpenAI::ArrayOf[Participant]
end

response = openai.responses.create(
  model: "{{ site.models.openai_latest }}",
  input: [
    {role: :system, content: "Extract the event information."},
    {
      role: :user,
      content: <<~CONTENT
        Alice Shah and Lena are going to a science fair on Friday at 123 Main St. in San Diego.
        They have also invited Jasper Vellani and Talia Groves - Jasper has not responded and Talia said she is thinking about it.
      CONTENT
    }
  ],
  text: CalendarEvent
)

response
  .output
  .flat_map { _1.content }
  .grep_v(OpenAI::Models::Responses::ResponseOutputRefusal)
  .each do |content|
    pp(content.parsed)
  end
```

RubyLLM takes a schema class on the chat and hands back the parsed result:

```ruby
class CalendarEvent < Schematist::Schema
  string :name
  string :date

  array :participants do
    object do
      string :first_name
      string :last_name, required: false
      string :status, enum: %w[confirmed unconfirmed tentative]
    end
  end
end

chat = RubyLLM.chat model: "{{ site.models.openai_latest }}"
chat.with_instructions "Extract the event information."
chat.with_schema CalendarEvent

event = chat.ask <<~CONTENT
  Alice Shah and Lena are going to a science fair on Friday at 123 Main St. in San Diego.
  They have also invited Jasper Vellani and Talia Groves - Jasper has not responded and Talia said she is thinking about it.
CONTENT

event.parsed["participants"]
```

The same schema works with Anthropic, Gemini, and the other providers that support structured output. See [Structured Output]({% link _core_features/structured-output.md %}).

## Rails and Cost

The SDKs stop at the HTTP response. Neither has a Rails integration, and both report token counts without a price: `message.usage` and `response.usage`.

In RubyLLM, a chat can be an Active Record model, and responses carry their cost, or `nil` when the price is unknown:

```ruby
class Chat < ApplicationRecord
  acts_as_chat
end

chat = Chat.create! model: "{{ site.models.anthropic_opus }}"
response = chat.ask "Hello, Claude"

response.cost.total
chat.cost.total
```

Messages, tool calls, and a usage ledger are stored as they happen. See [Rails Integration]({% link _getting_started/rails.md %}) and [Cost and Usage Tracking]({% link _core_features/cost-and-usage-tracking.md %}).

## Day-One Parameters

When a vendor ships a parameter before RubyLLM has a name for it, you do not have to wait. `with_provider_options` merges fields in the provider's own vocabulary into the request:

```ruby
chat = RubyLLM.chat model: "{{ site.models.openai_latest }}"
chat.with_provider_options service_tier: "flex"
chat.ask "Summarize this week's support tickets."
```

New headers, such as beta flags, go through `with_headers`. Once two or more providers offer the same feature, RubyLLM gives it one name across all of them. See [Request Control]({% link _core_features/chat-request-control.md %}).

## When to Choose an Official SDK

* **You use one vendor, and only its model API.** The SDK mirrors that API exactly, with types for every request and response.
* **You need endpoints outside the model call.** Fine-tuning, vector stores, admin keys, webhooks, Realtime sessions, and OpenAI's hosted Agents API are account and platform features RubyLLM does not wrap.
* **You want typed models.** `OpenAI::BaseModel` and `Anthropic::BaseModel` give Sorbet-friendly types, which RubyLLM's Hash results do not.

## When to Choose RubyLLM

* **You want to switch or mix providers** without rewriting call sites.
* **You want the loop handled**, with streaming, approvals, and persistence included.
* **You build on Rails**, and want chats, tool calls, and cost stored as records.
* **You want one gem for every operation**: chat, images, speech, transcription, OCR, moderation, embeddings, and reranking.

You can also use both: RubyLLM for your application's model calls, and an official SDK for the platform endpoints it does not cover.

## Next Steps

* [Getting Started]({% link _getting_started/getting-started.md %}) - Install RubyLLM and make your first call.
* [Request Control]({% link _core_features/chat-request-control.md %}) - Provider options, headers, and other request settings.
* [Migrating from ruby-openai]({% link _compare/migrate-ruby-openai.md %}) - Move an existing OpenAI client app to RubyLLM.

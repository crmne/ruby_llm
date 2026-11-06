---
layout: default
title: ruby-openai
seo:
  title: Migrating from ruby-openai
nav_order: 8
description: Move a ruby-openai application to RubyLLM one call site at a time, with before and after code for chat, streaming, and tools.
permalink: /migrate/ruby-openai/
---

# Migrating from ruby-openai

{{ page.description }}
{: .fs-6 .fw-300 }

After reading this guide, you will know:

* How to run ruby-openai and RubyLLM side by side while you migrate.
* How chat, conversations, streaming, and function calling translate.
* Where embeddings, images, audio, and moderation calls go.
* What RubyLLM gives you that a client library does not.
* When to keep ruby-openai.

> **Last checked** on 5 November 2026 against RubyLLM 2.2 and ruby-openai 8.3.0, released 29 August 2025. The ruby-openai code comes from its [README](https://github.com/alexrudall/ruby-openai#readme): [Quickstart](https://github.com/alexrudall/ruby-openai#quickstart), [With Config](https://github.com/alexrudall/ruby-openai#with-config), [Chat](https://github.com/alexrudall/ruby-openai#chat), [Streaming Chat](https://github.com/alexrudall/ruby-openai#streaming-chat), and [Functions](https://github.com/alexrudall/ruby-openai#functions). Model names were changed so both sides call the same model, and inline comments were removed.

## Why Move

ruby-openai is a client for OpenAI's HTTP API. You send the request body OpenAI documents and get its JSON back as a Hash. That keeps you close to the wire, and it leaves the rest to you: the message array, the tool loop, the stream assembly, and the bookkeeping.

RubyLLM is a framework around the model call. A chat keeps its own transcript, a tool is a Ruby class, a streamed answer arrives as a block and still returns the complete message, and every response knows its tokens and its cost in dollars. The same code runs on OpenAI, Anthropic, Gemini, and the other [providers]({% link _reference/configuration-providers.md %}), and in Rails a chat is an Active Record model.

## Installing Both

The two gems do not share constants, so you can add RubyLLM and move call sites one at a time:

```ruby
# Gemfile
gem "ruby-openai"
gem "ruby_llm"
```

Before, with ruby-openai:

```ruby
OpenAI.configure do |config|
  config.access_token = ENV.fetch("OPENAI_ACCESS_TOKEN")
end

client = OpenAI::Client.new
```

After, with RubyLLM:

```ruby
RubyLLM.configure do |config|
  config.openai_api_key = ENV.fetch("OPENAI_ACCESS_TOKEN")
end
```

There is no client to pass around. `RubyLLM.chat`, `RubyLLM.embed`, and the other entry points read the configuration. See [Configuration]({% link _getting_started/configuration.md %}) for every option, including per-tenant keys.

## Chat

Before:

```ruby
response = client.chat(
  parameters: {
    model: "{{ site.models.openai_latest }}",
    messages: [{ role: "user", content: "Hello!" }]
  }
)
puts response.dig("choices", 0, "message", "content")
```

After:

```ruby
chat = RubyLLM.chat model: "{{ site.models.openai_latest }}"
response = chat.ask "Hello!"

puts response.content
```

`response` is a `RubyLLM::Message`, not a Hash. It has `content`, `tokens`, `cost`, and `model_id` as readers.

## Conversations

With ruby-openai, the conversation is the array you send. Each turn, you append the assistant's reply and the next question yourself, as the README's Functions example does:

```ruby
messages = [{ role: "user", content: "Hello!" }]
response = client.chat(parameters: { model: "{{ site.models.openai_latest }}", messages: messages })

messages << response.dig("choices", 0, "message")
messages << { role: "user", content: "Tell me more." }
client.chat(parameters: { model: "{{ site.models.openai_latest }}", messages: messages })
```

A RubyLLM chat keeps its transcript, so the second question is just the second question:

```ruby
chat = RubyLLM.chat model: "{{ site.models.openai_latest }}"
chat.ask "Hello!"
chat.ask "Tell me more."
```

`chat.messages` returns the whole transcript when you need it. Instructions that were a `system` message become `chat.with_instructions "..."`.

## Streaming

Before:

```ruby
client.chat(
  parameters: {
    model: "{{ site.models.openai_latest }}",
    messages: [{ role: "user", content: "Describe a character called Anna!" }],
    stream: proc do |chunk, _event|
      print chunk.dig("choices", 0, "delta", "content")
    end
  }
)
```

After:

```ruby
chat.ask "Describe a character called Anna!" do |chunk|
  print chunk.content
end
```

With ruby-openai, the streamed request returns no assembled message, so you collect the deltas yourself if you want to keep the answer. RubyLLM's `ask` still returns the complete `Message`, with its token counts and cost, after the last chunk. See [Streaming]({% link _core_features/streaming.md %}).

## Function Calling

This is where the code shrinks the most. The ruby-openai README defines the function's JSON schema, sends it, checks the reply for tool calls, parses the arguments, dispatches by name, appends the results, and sends a second request:

```ruby
def get_current_weather(location:, unit: "fahrenheit")
  "The weather in #{location} is nice 🌞 #{unit}"
end

messages = [
  {
    "role": "user",
    "content": "What is the weather like in San Francisco?",
  },
]

response =
  client.chat(
    parameters: {
      model: "{{ site.models.openai_latest }}",
      messages: messages,
      tools: [
        {
          type: "function",
          function: {
            name: "get_current_weather",
            description: "Get the current weather in a given location",
            parameters: {
              type: :object,
              properties: {
                location: {
                  type: :string,
                  description: "The city and state, e.g. San Francisco, CA",
                },
                unit: {
                  type: "string",
                  enum: %w[celsius fahrenheit],
                },
              },
              required: ["location"],
            },
          },
        }
      ],
      tool_choice: "required"
    },
  )

message = response.dig("choices", 0, "message")

if message["role"] == "assistant" && message["tool_calls"]
  messages << message

  message["tool_calls"].each do |tool_call|
    tool_call_id = tool_call.dig("id")
    function_name = tool_call.dig("function", "name")
    function_args = JSON.parse(
      tool_call.dig("function", "arguments"),
      { symbolize_names: true },
    )
    function_response =
      case function_name
      when "get_current_weather"
        get_current_weather(**function_args)
      else
        # decide how to handle
      end

    messages << {
      tool_call_id: tool_call_id,
      role: "tool",
      name: function_name,
      content: function_response
    }
  end

  second_response = client.chat(
    parameters: {
      model: "{{ site.models.openai_latest }}",
      messages: messages
    }
  )

  puts second_response.dig("choices", 0, "message", "content")
end
```

In RubyLLM, the function becomes a tool class. Its `parameters` block is the schema, and `execute` is the method:

```ruby
class CurrentWeather < RubyLLM::Tool
  description "Get the current weather in a given location"

  parameters do
    string :location, description: "The city and state, e.g. San Francisco, CA"
    string :unit, enum: %w[celsius fahrenheit], required: false
  end

  def execute(location:, unit: "fahrenheit") = "The weather in #{location} is nice 🌞 #{unit}"
end

chat = RubyLLM.chat model: "{{ site.models.openai_latest }}"
chat.with_tools CurrentWeather
chat.with_tool_options choice: :required

response = chat.ask "What is the weather like in San Francisco?"

puts response.content
```

RubyLLM runs the loop: it sends the schema, executes each call the model makes, sends the results back, and repeats until the model answers. That works when the model calls several tools, or the same tool several times, which the README example would need another loop for. For simple tools you can drop the `parameters` block, and RubyLLM reads the keyword arguments of `execute` instead.

`with_tool_options choice: :required` is the README's `tool_choice: "required"`. RubyLLM clears it once the tool has run, so the model can answer. See [Tools]({% link _getting_started/tools.md %}) and [Controlling Tool Execution]({% link _tools/tool-execution.md %}).

## Everything Else

The rest of ruby-openai's endpoints map to RubyLLM operations that work across providers:

| ruby-openai | RubyLLM |
| --- | --- |
| `client.embeddings` | [`RubyLLM.embed`]({% link _getting_started/embeddings.md %}) |
| `client.images.generate` | [`RubyLLM.paint`]({% link _getting_started/image-generation.md %}) |
| `client.audio.transcribe` | [`RubyLLM.transcribe`]({% link _getting_started/audio-transcription.md %}) |
| `client.audio.speech` | [`RubyLLM.speak`]({% link _getting_started/text-to-speech.md %}) |
| `client.moderations` | [`RubyLLM.moderate`]({% link _getting_started/moderation.md %}) |
| `client.batches` | [`RubyLLM.batch`]({% link _advanced/batches.md %}) |
| `response_format: { type: "json_object" }` | `with_provider_options text: { format: { type: "json_object" } }`, or [`with_schema`]({% link _core_features/structured-output.md %}) to enforce a schema |
| Image URLs in `content` parts | `chat.ask "...", with: "photo.jpg"` ([Attachments]({% link _core_features/attachments.md %})) |
| `uri_base` for Ollama, Groq, or Gemini | `provider:` with RubyLLM's native [providers]({% link _reference/configuration-providers.md %}) |

Request fields RubyLLM does not name yet still reach the API. Pass them in OpenAI's own vocabulary with `with_provider_options`. RubyLLM talks to OpenAI through the Responses API, so use its field names: a Chat Completions field such as `response_format` does not always carry over unchanged. See [Request Control]({% link _core_features/chat-request-control.md %}).

## What You Gain

* **Every provider through the same calls.** Change `model: "{{ site.models.openai_latest }}"` to `model: "{{ site.models.anthropic_latest }}"` and the tool, the stream, and the schema keep working.
* **Cost.** `response.cost.total` and `chat.cost.total` are in dollars, from the model registry. See [Cost and Usage Tracking]({% link _core_features/cost-and-usage-tracking.md %}).
* **Rails.** `acts_as_chat` stores chats, messages, and tool calls as your records, and `bin/rails generate ruby_llm:chat_ui` gives you a streaming chat interface. See [Rails Integration]({% link _getting_started/rails.md %}).
* **Agents.** A `RubyLLM::Agent` class keeps the model, instructions, and tools in one place for controllers, jobs, and services. See [Agents]({% link _getting_started/agents.md %}).

## When to Keep ruby-openai

* **You use OpenAI-hosted state.** Assistants, Threads, Runs, Conversations, and Vector Stores keep conversations and files on OpenAI's servers. RubyLLM keeps the conversation in your application by design, so it does not wrap them.
* **You manage OpenAI itself.** Fine-tuning jobs, Admin API keys, and the Usage API are account operations, not model calls.
* **You want the raw JSON.** If your code is built around OpenAI's response Hashes, ruby-openai hands them to you unchanged.

Nothing stops you from keeping both: RubyLLM for chats and operations, ruby-openai for the account endpoints.

## Next Steps

* [Getting Started]({% link _getting_started/getting-started.md %}) - Install RubyLLM and make your first call.
* [Tools]({% link _getting_started/tools.md %}) - Define tools and let the model call them.
* [Rails Integration]({% link _getting_started/rails.md %}) - Persist chats as Active Record models.

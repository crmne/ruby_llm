---
layout: default
title: Getting Started
nav_order: 1
description: Install RubyLLM and build with chats, tools, agents, images, video, audio, and document processing in Ruby and Rails.
redirect_from:
  - /guides/getting-started
  - /installation
---

# {{ page.title }}

{{ page.description }}
{: .fs-6 .fw-300 }

After reading this guide, you will know:

*   How to install RubyLLM.
*   How to configure the providers you want to use.
*   How to chat, stream responses, and ask about files.
*   How to define tools, agents, and structured output.
*   How to generate images, video, and speech, and transcribe audio.
*   How to extract document text, moderate content, and search with embeddings and reranking.
*   How to track costs and save conversations in Rails.

Each example shows one feature. Try the ones your application needs, then follow its guide for more options.

## Installation

Add the RubyLLM 2.0 release candidate with Bundler:

```sh
bundle add ruby_llm --version 2.0.0.rc2
```

## Minimal Configuration

Start with an OpenAI API key. Put this configuration at the start of your script, or in `config/initializers/ruby_llm.rb` in Rails:

```ruby
require 'ruby_llm'

RubyLLM.configure do |config|
  config.openai_api_key = ENV.fetch('OPENAI_API_KEY')
end
```

Most examples below use OpenAI. The video, OCR, and reranking examples show the additional provider keys they need. Configure only the providers you use. See [Configuration]({% link _getting_started/configuration.md %}) for other providers and local models.

## Your First Chat

Ask a question and read the response:

```ruby
chat = RubyLLM.chat

response = chat.ask "What is Ruby on Rails?"

puts response.content
# => "Ruby on Rails, often shortened to Rails, is a server-side web application..."
```

The chat remembers the conversation, so you can follow up:

```ruby
response = chat.ask "How do I create my first Rails app?"
puts response.content
```

See [Chatting with AI Models]({% link _core_features/chat.md %}) for choosing models and setting instructions.

## Streaming a Response

Pass a block to `ask` and RubyLLM yields chunks as they arrive:

```ruby
chat.ask "Tell me a story about a Ruby programmer" do |chunk|
  print chunk.content
end
```

See the [Streaming Guide]({% link _core_features/streaming.md %}) for streaming into web pages and background jobs.

## Asking About Files

Pass an image or PDF with `with:`:

```ruby
chat = RubyLLM.chat
response = chat.ask "Summarize this document", with: "report.pdf"
puts response.content
```

Use your own files in these examples. See [Attachments]({% link _core_features/attachments.md %}) for supported formats, URLs, and Active Storage files.

## Getting Structured Output

Describe the fields you want in a Ruby schema, then read the result as a Hash:

```ruby
class PersonSchema < Schematist::Schema
  string :name
  integer :age
end

response = RubyLLM.chat.with_schema(PersonSchema).ask "Alice is 30 years old."
response.parsed
# => {"name" => "Alice", "age" => 30}
```

Schematist comes with RubyLLM. See [Structured Output]({% link _core_features/structured-output.md %}) for nested objects, arrays, and optional fields.

## Giving the Model Tools

Let the model call your Ruby code. Define a tool and implement `execute`:

```ruby
class CurrentTime < RubyLLM::Tool
  description "Returns the current date, time, and time zone"

  def execute
    Time.now.to_s
  end
end

response = RubyLLM.chat.with_tools(CurrentTime).ask "What day is it?"
puts response.content
```

RubyLLM runs the tool calls and returns their results to the model. See [Tools]({% link _core_features/tools.md %}) for parameters and [Tool Execution]({% link _core_features/tool-execution.md %}) for human approvals.

## Defining an Agent

Give an agent its model, instructions, and tools in a Ruby class. This one uses the `CurrentTime` tool above:

```ruby
class PlanningAssistant < RubyLLM::Agent
  model "{{ site.models.default_chat }}"
  instructions "Help plan the week. Check the current date before suggesting dates."
  tools CurrentTime
end

response = PlanningAssistant.new.ask "Help me plan a three-day Ruby study schedule."
puts response.content
```

See [Agents]({% link _advanced/agents.md %}) for reusable prompts, inputs, and Rails persistence, or [Agentic Workflows]({% link _advanced/agentic-workflows.md %}) for coordinating agents.

## Generating an Image

Generate an image and save it:

```ruby
image = RubyLLM.paint "A photorealistic red panda coding Ruby"
image.save "red_panda.png"
```

See [Image Generation]({% link _core_features/image-generation.md %}) for editing images, choosing sizes, and generating several at once.

## Generating a Video

Generate a video and save it the same way. The default video model uses xAI, so add its key to your configuration:

```ruby
RubyLLM.configure do |config|
  config.xai_api_key = ENV.fetch('XAI_API_KEY')
end
```

```ruby
video = RubyLLM.animate "A red panda typing on a laptop, with rain at the window"
video.save "red_panda.mp4"
```

`animate` waits for the video to finish. See [Video Generation]({% link _core_features/video-generation.md %}) for other providers, animating an image, and submitting jobs with `animate_later`.

## Generating Speech

Turn text into an audio file:

```ruby
speech = RubyLLM.speak "Welcome to your first RubyLLM application."
speech.save "welcome.mp3"
```

See [Text to Speech]({% link _core_features/text-to-speech.md %}) for voices, languages, and audio formats.

## Transcribing Audio

Turn a recording into text:

```ruby
transcript = RubyLLM.transcribe "meeting.wav"
puts transcript.text
```

See [Audio Transcription]({% link _core_features/audio-transcription.md %}) for timestamps, speaker identification, and streaming.

## Extracting Text from Documents

Extract text from PDFs and scanned images as Markdown. OCR uses Mistral, so add its key:

```ruby
RubyLLM.configure do |config|
  config.mistral_api_key = ENV.fetch('MISTRAL_API_KEY')
end
```

```ruby
document = RubyLLM.ocr "scanned-contract.pdf"
puts document.markdown
```

See [Document OCR]({% link _core_features/ocr.md %}) for extracting individual pages and working with tables.

## Moderating Content

Check whether the model flags text for moderation:

```ruby
moderation = RubyLLM.moderate "I love programming in Ruby."
moderation.flagged?
# => false
```

See [Moderation]({% link _core_features/moderation.md %}) for categories, scores, and image moderation.

## Creating an Embedding

Turn text into a vector for similarity search:

```ruby
embedding = RubyLLM.embed "Ruby is optimized for programmer happiness."
vector = embedding.vectors
```

See [Embeddings]({% link _core_features/embeddings.md %}) for embedding multiple documents and [RAG]({% link _advanced/rag.md %}) for answering questions from your own content.

## Ranking Search Results

Order candidate documents by how well they answer a question. This example uses Cohere:

```ruby
RubyLLM.configure do |config|
  config.cohere_api_key = ENV.fetch('COHERE_API_KEY')
end
```

```ruby
documents = ["Reset your password in Settings.", "Invoices arrive by email."]
ranked = RubyLLM.rerank("How do I reset my password?", documents,
                       model: "{{ site.models.rerank_cohere }}")
puts ranked.results.first.document
```

See [Reranking]({% link _core_features/rerank.md %}) for scores, result limits, and combining it with embeddings.

## Tracking Usage and Costs

Read token counts and costs from the response:

```ruby
response = RubyLLM.chat.ask "Explain Ruby blocks in one paragraph."
response.tokens.input
response.tokens.output
response.cost.total
```

See [Cost and Usage Tracking]({% link _core_features/cost-and-usage-tracking.md %}) for cache usage, retries, and the Rails usage ledger. Use [Batches]({% link _advanced/batches.md %}) for bulk work that can run asynchronously.

## Using It in Rails

Use the install generator to create Chat and Message models with Active Record persistence:

```bash
bin/rails generate ruby_llm:install
bin/rails db:migrate
bin/rails ruby_llm:load_models
```

```ruby
chat = Chat.create!(model: "{{ site.models.default_chat }}")
chat.ask "What's the best way to learn Rails?"
```

The API stays the same, and each message persists automatically. Pass Active Storage attachments with `with:`, just as you pass files in plain Ruby. Optionally, add a ready-to-use chat interface with Hotwire streaming, controllers, and an Active Job:

```bash
bin/rails generate ruby_llm:chat_ui
```

Then visit `http://localhost:3000/chats` to start chatting. See the [Rails Integration Guide]({% link _advanced/rails.md %}) for full details.

## What's Next?

Continue with the guide for the feature you want to build:

*   [Chatting with AI Models]({% link _core_features/chat.md %})
*   [Models]({% link _reference/available-models.md %}) for comparing capabilities and pricing
*   [Agents]({% link _advanced/agents.md %}) and [Agentic Workflows]({% link _advanced/agentic-workflows.md %})
*   [Batches]({% link _advanced/batches.md %}) and [Prompt Caching]({% link _core_features/prompt-caching.md %})
*   [Rails Integration]({% link _advanced/rails.md %})
*   [AI Coding Assistants]({% link _getting_started/ai-coding-assistants.md %})
*   [Configuration]({% link _getting_started/configuration.md %})
*   [Error Handling]({% link _advanced/error-handling.md %})

---
layout: default
title: Getting Started
nav_order: 1
description: Install RubyLLM and build a small support desk with chats, tools, agents, structured output, and audio and document processing.
redirect_from:
  - /guides/getting-started
  - /installation
---

# {{ page.title }}

{{ page.description }}
{: .fs-6 .fw-300 }

After reading this guide, you will know:

*   How to install and configure RubyLLM.
*   How to chat with a model, stream its answer, and ask about files.
*   How to get structured data back and read what a request cost.
*   How to give the model tools and put them in an agent.
*   How to transcribe audio, read documents, moderate messages, search with embeddings and reranking, and generate images, video, and speech.
*   How to save conversations in Rails.

This guide builds pieces of a support desk for Acme Outfitters, an online clothing store. Customers write in about orders, returns, and invoices, and RubyLLM helps answer them. Each section shows one feature in a few lines. The rest of Start Here builds on the same example, one guide per feature.

## Installation

{% if site.docs_unreleased %}
These guides cover unreleased changes on `main`. Install from GitHub to use them:

```sh
bundle add ruby_llm --git https://github.com/crmne/ruby_llm --branch main
```
{% else %}
Add RubyLLM 2.2 with Bundler:

```sh
bundle add ruby_llm --version 2.2.1
```
{% endif %}

{% assign legacy_docs = site.data.versions.items | where: 'id', 'v1' | first %}
For an existing 1.x application, use the [1.x docs]({{ legacy_docs.url }}) or follow the [upgrade guide]({% link _reference/upgrading.md %}) before switching versions.
{: .warning }

RubyLLM works with JSON 2 and JSON 3. JSON 3 rejects an option that older Rails versions pass to it. Rails 7.2.4 and 8.1.3 removed that option. On earlier versions, and on Rails 8.0, keep JSON 2 in your Gemfile:

```ruby
gem "json", "< 3"
```

## Configuring a Provider

Start with an OpenAI API key. Put this at the top of your script, or in `config/initializers/ruby_llm.rb` in Rails:

```ruby
require "ruby_llm"

RubyLLM.configure do |config|
  config.openai_api_key = ENV.fetch("OPENAI_API_KEY")
end
```

Most examples here use OpenAI. The video, OCR, and reranking examples add the keys they need. Configure only the providers you use; see [Configuration]({% link _getting_started/configuration.md %}) for the others and for local models.

## Your First Chat

A customer writes that their parcel arrived damaged. Ask the model for a reply:

```ruby
chat = RubyLLM.chat

response = chat.ask "A customer says their parcel arrived damaged. Draft a short, friendly reply."
puts response.content
# => "I'm so sorry your parcel arrived damaged. Could you send a photo of..."
```

The chat remembers the conversation, so you can refine the answer:

```ruby
chat.ask "Make it shorter, and offer a replacement."
```

See [Chat]({% link _getting_started/chat.md %}) for instructions, choosing models, and continuing conversations.

## Streaming the Answer

Pass a block to `ask`, and RubyLLM yields the answer in chunks as the model writes it:

```ruby
chat.ask "Now write the same reply in German." do |chunk|
  print chunk.content
end
```

See [Streaming]({% link _core_features/streaming.md %}) for streaming into web pages and background jobs.

## Asking About Files

Customers send screenshots and PDFs. Pass a file with `with:`:

```ruby
response = RubyLLM.chat.ask "What error does this checkout screenshot show?", with: "screenshot.png"
puts response.content
```

`with:` takes a path, a URL, an IO, or an Active Storage attachment. See [Attachments]({% link _core_features/attachments.md %}) for supported formats.

## Getting Structured Data Back

Before anyone reads a support email, triage it: what it's about, how urgent it is, and a one-line summary. Describe those fields in a schema, and read the answer as a Hash:

```ruby
class TicketTriage < Schematist::Schema
  string :category, enum: %w[billing shipping returns other]
  string :priority, enum: %w[low normal urgent]
  string :summary, description: "One sentence for the support queue"
end

email = "My order R-1042 still hasn't arrived and I need it for a wedding on Saturday!"
triage = RubyLLM.chat.with_schema(TicketTriage).ask(email).parsed
# => {"category" => "shipping", "priority" => "urgent", "summary" => "Order R-1042 is late; needed by Saturday."}
```

Schematist comes with RubyLLM. See [Structured Output]({% link _core_features/structured-output.md %}) for nested objects, arrays, and optional fields.

## Reading Usage and Costs

Every response knows its tokens and what it cost:

```ruby
response = RubyLLM.chat.ask "Summarize our returns policy in one sentence."
response.tokens.input
response.tokens.output
response.cost.total
```

See [Cost and Usage Tracking]({% link _core_features/cost-and-usage-tracking.md %}) for cached tokens, retries, and the Rails usage ledger, and [Batches]({% link _advanced/batches.md %}) for bulk work at a lower price.

## Giving the Model Tools

The model doesn't know your help center. A tool lets it search it: a Ruby class with a description and an `execute` method.

```ruby
class SearchDocs < RubyLLM::Tool
  description "Searches the help center for articles that answer a customer's question"
  parameter :query, description: "What the customer wants to know"

  def execute(query:)
    Article.search(query).first(3).map do |article|
      { title: article.title, url: article.url, body: article.body }
    end
  end
end

response = RubyLLM.chat.with_tools(SearchDocs).ask "How do I return a jacket that doesn't fit?"
puts response.content
```

`Article.search` stands for whatever search your application already has. When the model calls the tool, RubyLLM runs `execute` and sends the result back to the model, which then answers. See [Tools]({% link _getting_started/tools.md %}) for tools that act for the current customer.

## Defining an Agent

The support chat needs the same model, instructions, and tools everywhere it runs. Put them in an agent:

```ruby
class SupportAgent < RubyLLM::Agent
  model "{{ site.models.default_chat }}"
  instructions "You answer customers of Acme Outfitters. Be brief and friendly, and link to articles you used."
  tools SearchDocs
end

response = SupportAgent.new.ask "Do you ship to Canada?"
puts response.content
```

See [Agents]({% link _getting_started/agents.md %}) for runtime inputs, prompts, callbacks, and subagents, and [Agentic Workflows]({% link _advanced/agentic-workflows.md %}) for agents that work together.

## Transcribing a Voicemail

Not every customer writes. Turn a voicemail into text, then handle it like an email:

```ruby
transcript = RubyLLM.transcribe "voicemail.mp3"
puts transcript.text
```

See [Audio Transcription]({% link _getting_started/audio-transcription.md %}) for timestamps, speaker identification, and streaming.

## Reading an Invoice

A customer disputes a charge and attaches a scanned invoice. OCR extracts its text as Markdown. It uses Mistral, so add its key:

```ruby
RubyLLM.configure do |config|
  config.mistral_api_key = ENV.fetch("MISTRAL_API_KEY")
end
```

```ruby
invoice = RubyLLM.ocr "invoice.pdf"
puts invoice.markdown
```

See [Document OCR]({% link _getting_started/ocr.md %}) for single pages and tables.

## Moderating a Message

Check a message before an agent reads it or a person sees it:

```ruby
moderation = RubyLLM.moderate "Your courier threw my parcel over the fence. Again."
moderation.flagged?
# => false
```

See [Moderation]({% link _getting_started/moderation.md %}) for categories, scores, and images.

## Searching the FAQ

Embeddings turn text into vectors, so you can find the answers closest in meaning to a question, not just in wording. Embed the FAQ once and store the vectors:

```ruby
faq = [
  "Returns are free within 30 days of delivery.",
  "Orders ship within two business days.",
  "We ship to the EU, the UK, and the US."
]

embedding = RubyLLM.embed faq
embedding.vectors # => one vector per answer
```

A vector search returns candidates. Reranking puts the best answer first. This example uses Cohere:

```ruby
RubyLLM.configure do |config|
  config.cohere_api_key = ENV.fetch("COHERE_API_KEY")
end
```

```ruby
ranked = RubyLLM.rerank "Can I send back a jacket?", faq, model: "{{ site.models.rerank_cohere }}"
ranked.results.first.document
# => "Returns are free within 30 days of delivery."
```

See [Embeddings]({% link _getting_started/embeddings.md %}), [Reranking]({% link _getting_started/rerank.md %}), and [RAG]({% link _advanced/rag.md %}) for answering questions from your own content.

## Generating Images, Video, and Speech

The help center needs an illustration for its returns article:

```ruby
image = RubyLLM.paint "A friendly flat illustration of a parcel being packed for return"
image.save "returns.png"
```

And a short clip for its packing guide. The default video model uses xAI, so add its key:

```ruby
RubyLLM.configure do |config|
  config.xai_api_key = ENV.fetch("XAI_API_KEY")
end
```

```ruby
video = RubyLLM.animate "Hands folding a sweater and packing it into a cardboard box"
video.save "packing.mp4"
```

The phone line reads replies aloud:

```ruby
speech = RubyLLM.speak "Thanks for calling Acme Outfitters. Your order shipped this morning."
speech.save "reply.mp3"
```

`animate` waits for the video to finish. See [Image Generation]({% link _getting_started/image-generation.md %}), [Video Generation]({% link _advanced/video-generation.md %}), and [Text to Speech]({% link _getting_started/text-to-speech.md %}) for sizes, voices, formats, and background jobs.

## Using It in Rails

The install generator creates Chat and Message models backed by Active Record:

```bash
bin/rails generate ruby_llm:install
bin/rails db:migrate
bin/rails ruby_llm:load_models
```

```ruby
chat = Chat.create!(model: "{{ site.models.default_chat }}")
chat.ask "Do you ship to Canada?"
```

The API stays the same, and each message is saved as it arrives. For a working chat interface with Hotwire streaming, add:

```bash
bin/rails generate ruby_llm:chat_ui
```

Then visit `http://localhost:3000/chats`. See [Rails Integration]({% link _getting_started/rails.md %}) for the full setup.

## Next Steps

The Start Here guides take each piece in turn:

1.  [How RubyLLM Works]({% link _getting_started/overview.md %}): how the pieces fit together.
2.  [Chat]({% link _getting_started/chat.md %}): conversations, instructions, models, and thinking.
3.  [Tools]({% link _getting_started/tools.md %}): `SearchDocs`, `LookupOrder`, and tools that act for the current customer.
4.  [Agents]({% link _getting_started/agents.md %}): `SupportAgent`, inputs, prompts, callbacks, and subagents.
5.  [Configuration]({% link _getting_started/configuration.md %}): API keys, default models, and contexts.
6.  The individual operations: [images]({% link _getting_started/image-generation.md %}), [speech]({% link _getting_started/text-to-speech.md %}), [transcription]({% link _getting_started/audio-transcription.md %}), [OCR]({% link _getting_started/ocr.md %}), [moderation]({% link _getting_started/moderation.md %}), [embeddings]({% link _getting_started/embeddings.md %}), and [reranking]({% link _getting_started/rerank.md %}).
7.  [Rails Integration]({% link _getting_started/rails.md %}): the support desk on your own records and jobs.

Then go deeper where your application needs it: [Chat in Depth]({% link _core_features/streaming.md %}) and [Tools in Depth]({% link _tools/tool-parameters.md %}) for every option, [Agentic Workflows]({% link _advanced/agentic-workflows.md %}) for routing and parallel work, [Durable Agents]({% link _advanced/durable-agents-overview.md %}) for agents that wait for people, [Error Handling]({% link _advanced/error-handling.md %}) for failures, and [Models]({% link _reference/available-models.md %}) for capabilities and prices. If you write code with an AI assistant, see [AI Coding Assistants]({% link _reference/ai-coding-assistants.md %}). If you're moving from another framework or client, see [Migrating to RubyLLM]({% link _compare/migrating-from.md %}).

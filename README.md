<div align="center">

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="/docs/assets/images/logotype_dark.svg">
  <img src="/docs/assets/images/logotype.svg" alt="RubyLLM" height="120" width="250">
</picture>

<strong>Build AI features the Ruby way</strong>

<p>RubyLLM is the Ruby-native AI framework. Work with models, tools, and agents through one consistent API, in plain Ruby or Rails.</p>

[Website](https://rubyllm.com/) · [Getting Started](https://rubyllm.com/getting-started/) · [What's New in 2.0](https://rubyllm.com/whats-new-in-2-0/)

Battle tested at [<picture><source media="(prefers-color-scheme: dark)" srcset="https://chatwithwork.com/logotype-dark.svg"><img src="https://chatwithwork.com/logotype.svg" alt="Chat with Work" height="30" align="absmiddle"></picture>](https://chatwithwork.com) - *Fully private work AI*

[![Gem Version](https://badge.fury.io/rb/ruby_llm.svg)](https://badge.fury.io/rb/ruby_llm)
[![Ruby Style Guide](https://img.shields.io/badge/code_style-rubocop-brightgreen.svg)](https://github.com/rubocop/rubocop)
[![Gem Downloads](https://img.shields.io/gem/dt/ruby_llm)](https://rubygems.org/gems/ruby_llm)
[![codecov](https://codecov.io/gh/crmne/ruby_llm/branch/main/graph/badge.svg)](https://codecov.io/gh/crmne/ruby_llm)

<a href="https://trendshift.io/repositories/13640" target="_blank"><img src="https://trendshift.io/api/badge/repositories/13640" alt="crmne%2Fruby_llm | Trendshift" style="width: 250px; height: 55px;" width="250" height="55"/></a>
</div>

> [!NOTE]
> Using RubyLLM? [Share your story](https://tally.so/r/3Na02p)! Takes 5 minutes.

---

## 18 providers. One Ruby API.

Build with the models you want. Move between hosted and local providers without rewriting your application, or connect an OpenAI-compatible endpoint.

[Browse models and pricing](https://rubyllm.com/available-models/) · [Connect a provider](https://rubyllm.com/configuration-providers/)

## Start with one line. Add files, tools, and agents

These examples use **2.0.0**. Follow [Getting Started](https://rubyllm.com/getting-started/) to install it and configure the providers you want to try. For 1.x, use the [1.x docs](https://rubyllm.com/v1/).

```ruby
# Just ask
RubyLLM.chat.ask "What's the best way to learn Ruby?"
```

```ruby
# Ask about files with a model that supports their input types
chat = RubyLLM.chat(model: "gemini-3.7-flash")
chat.ask "What's in this image?", with: "ruby_conf.jpg"
chat.ask "What's happening in this video?", with: "video.mp4"
chat.ask "Describe this meeting", with: "meeting.wav"
chat.ask "Summarize this document", with: "contract.pdf"
chat.ask "Explain this code", with: "app.rb"
```

```ruby
# Multiple files at once
chat.ask "Analyze these files", with: ["diagram.png", "report.pdf", "notes.txt"]
```

```ruby
# Stream responses
chat.ask "Tell me a story about Ruby" do |chunk|
  print chunk.content
end
```

```ruby
# Generate images
image = RubyLLM.paint "a sunset over mountains in watercolor style"
image.save "sunset.png"
```

```ruby
# Generate videos
video = RubyLLM.animate "a paper boat sailing down a rainy gutter"
video.save "paper_boat.mp4"
```

```ruby
# Create embeddings
embedding = RubyLLM.embed "Ruby is elegant and expressive"
embedding.vectors
```

```ruby
# Rank search results
documents = ["Reset your password in Settings.", "Invoices arrive by email."]
ranked = RubyLLM.rerank("How do I reset my password?", documents, model: "rerank-v3.5")
ranked.results.first.document
```

```ruby
# Transcribe audio to text
transcript = RubyLLM.transcribe "meeting.wav"
puts transcript.text
```

```ruby
# Turn text into speech
speech = RubyLLM.speak "Hello, welcome to RubyLLM!"
speech.save "welcome.mp3"
```

```ruby
# Extract document text as markdown
document = RubyLLM.ocr "contract.pdf"
puts document.markdown
```

```ruby
# Check whether a moderation model flags content
RubyLLM.moderate("Some user-generated content").flagged?
```

```ruby
# Ask a typed question about your data
class Urgency < RubyLLM::Judge
  probability :urgent, "Does this need attention today?"
end

Urgency.judge("Please refund my duplicate charge today.").urgent.probability
```

```ruby
# Let AI use your code
class Weather < RubyLLM::Tool
  description "Get current weather"

  def execute(latitude:, longitude:)
    url = "https://api.open-meteo.com/v1/forecast?latitude=#{latitude}&longitude=#{longitude}&current=temperature_2m,wind_speed_10m"
    JSON.parse(Faraday.get(url).body)
  end
end

chat.with_tools(Weather).ask "What's the weather in Berlin?"
```

```ruby
# Define an agent with instructions + tools
class WeatherAssistant < RubyLLM::Agent
  model "gpt-5.6-luna"
  instructions "Be concise and always use tools for weather."
  tools Weather
end

WeatherAssistant.new.ask "What's the weather in Berlin?"
```

```ruby
# Get structured output
class ProductSchema < Schematist::Schema
  string :name
  number :price
  array :features do
    string
  end
end

response = chat.with_schema(ProductSchema).ask "Analyze this product", with: "product.txt"
response.parsed
```

## A complete AI framework for Ruby

Agents, workflows, RAG, images, audio, and video. Built in, with usage tracking and Rails integration to bring them into your app.

* **Chat:** Conversational AI with `RubyLLM.chat`
* **Vision:** Analyze images and videos
* **Audio:** Transcribe speech with `RubyLLM.transcribe` and generate it with `RubyLLM.speak`
* **Documents:** Ask questions about PDFs, text files, and other supported formats
* **OCR:** Turn documents into markdown with `RubyLLM.ocr`
* **Image generation:** Create images with `RubyLLM.paint`
* **Video generation:** Create videos with `RubyLLM.animate`
* **Embeddings:** Generate embeddings with `RubyLLM.embed`
* **Reranking:** Order retrieval candidates by relevance with `RubyLLM.rerank`
* **Moderation:** Content flags, categories, and scores with `RubyLLM.moderate`
* **Judgments:** Probabilities, choices, and scores with `RubyLLM::Judge` and `RubyLLM.judge`
* **Tools:** Let AI call your Ruby methods
* **Tool approval:** Park a run until a human approves with `requires_approval`
* **The agentic loop:** Drive it yourself with `ask_later`, `step`, and `complete?`
* **Provider tools:** Web search, code execution, and MCP connectors with `with_provider_tools`
* **Agents:** Reusable assistants with `RubyLLM::Agent`
* **Prompt templates:** ERB prompts in `app/prompts`, rendered with `RubyLLM.render_prompt`
* **Workflows:** Correlate multi-agent runs in your telemetry with `RubyLLM.workflow`
* **Structured output:** Define a Ruby schema and read the result with `response.parsed`
* **Streaming:** Real-time responses with blocks
* **Rails:** Active Record persistence, Active Storage attachments, Hotwire streaming, and generators
* **Files:** Upload once and reuse across chats with `RubyLLM.upload`
* **Prompt caching:** Turn on the provider's cache with `with_caching` and `cache_until_here`
* **Fallbacks and cancellation:** Retry on backup models with `with_fallbacks`, stop a run with `cancel`
* **Cost tracking:** A per-attempt usage ledger behind `chat.tokens` and `chat.cost`
* **Async:** Fiber-based concurrency
* **Model registry:** Browse capabilities, limits, and pricing across providers
* **Extended thinking:** Control, view, and persist model deliberation
* **Citations:** Normalized source citations from documents, search, and grounding
* **Batches:** Provider-side batch processing with provider-specific discounts via `RubyLLM.batch`
* **Compaction:** Let providers condense long conversations with `with_compaction`
* **Token counting:** Count a request before you send it with `count_tokens`
* **Providers:** OpenAI, Azure, xAI, Anthropic, Gemini, VertexAI, Bedrock, Cohere, DeepSeek, Mistral, Ollama, Ollama Cloud, OpenRouter, Perplexity, GPUStack, ElevenLabs, Deepgram, TypeSafe, and any OpenAI-compatible API

## Installation

Install RubyLLM 2.0:

```bash
bundle add ruby_llm --version 2.0.0
```

Configure a provider in your script, or in `config/initializers/ruby_llm.rb` in Rails:

```ruby
require 'ruby_llm'

RubyLLM.configure do |config|
  config.openai_api_key = ENV.fetch('OPENAI_API_KEY')
end
```

Configure the other providers used by the examples as needed: Gemini for files, xAI for video, Mistral for OCR, and Cohere for reranking. [Getting Started](https://rubyllm.com/getting-started/) shows each setup beside its example. Upgrading an existing app? Follow the [upgrade guide](https://rubyllm.com/upgrading/).

## Feels at home in Rails

Save conversations with Active Record and stream replies with Hotwire. The generators give you a working chat UI. Watch the two-minute demo.

https://github.com/user-attachments/assets/65422091-9338-47da-a303-92b918bd1345

```bash
# Install Rails Integration
bin/rails generate ruby_llm:install
bin/rails db:migrate
bin/rails ruby_llm:load_models

# Add Chat UI (optional)
bin/rails generate ruby_llm:chat_ui
```

```ruby
class Chat < ApplicationRecord
  acts_as_chat
end

chat = Chat.create! model: "gpt-5.6-luna"
chat.ask "What's in this file?", with: "report.pdf"
```

Start your Rails server and visit `http://localhost:3000/chats` to try the chat interface. See the [Rails guide](https://rubyllm.com/rails/) for persistence, streaming, and background jobs.

## AI coding assistants

Give your coding assistant the RubyLLM API and documentation that match your application. From your application directory, install the skill packaged with your gem:

```bash
npx skills add "$(bundle show ruby_llm)" --skill rubyllm
```

Choose your coding assistant and installation scope when prompted. See [AI Coding Assistants](https://rubyllm.com/ai-coding-assistants/) for setup and updates.

## Documentation

[Guides](https://rubyllm.com/getting-started/) · [API reference](https://rubyllm.com/api/) · [Models](https://rubyllm.com/available-models/) · [Upgrading](https://rubyllm.com/upgrading/) · [1.x docs](https://rubyllm.com/v1/)

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

Released under the MIT License.

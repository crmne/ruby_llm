<img src="/docs/assets/images/logotype.svg" alt="RubyLLM" height="120" width="250">

A delightful Ruby way to work with AI. No configuration madness, no complex callbacks, no handler hell – just beautiful, expressive Ruby code.

<div style="display: flex; align-items: center; flex-wrap: wrap; gap: 4px;">
  <img src="https://upload.wikimedia.org/wikipedia/commons/4/4d/OpenAI_Logo.svg" alt="OpenAI" height="40" width="120">
  &nbsp;&nbsp;&nbsp;&nbsp;
  <img src="https://upload.wikimedia.org/wikipedia/commons/7/78/Anthropic_logo.svg" alt="Anthropic" height="40" width="120">
  &nbsp;&nbsp;&nbsp;&nbsp;
  <img src="https://upload.wikimedia.org/wikipedia/commons/8/8a/Google_Gemini_logo.svg" alt="Google" height="40" width="120">
  &nbsp;&nbsp;&nbsp;&nbsp;
  <img src="https://upload.wikimedia.org/wikipedia/commons/e/ec/DeepSeek_logo.svg" alt="DeepSeek" height="40" width="120">
</div>

<a href="https://badge.fury.io/rb/ruby_llm"><img src="https://badge.fury.io/rb/ruby_llm.svg?dummy=unused" alt="Gem Version" /></a>
<a href="https://github.com/testdouble/standard"><img src="https://img.shields.io/badge/code_style-standard-brightgreen.svg" alt="Ruby Style Guide" /></a>
<a href="https://rubygems.org/gems/ruby_llm"><img alt="Gem Downloads" src="https://img.shields.io/gem/dt/ruby_llm"></a>
<a href="https://codecov.io/gh/crmne/ruby_llm"><img src="https://codecov.io/gh/crmne/ruby_llm/branch/main/graph/badge.svg" alt="codecov" /></a>

🤺 Battle tested at [💬  Chat with Work](https://chatwithwork.com)

## The problem with AI libraries

Every AI provider comes with its own client library, its own response format, its own conventions for streaming, and its own way of handling errors. Want to use multiple providers? Prepare to juggle incompatible APIs and bloated dependencies.

RubyLLM fixes all that. One beautiful API for everything. One consistent format. Minimal dependencies — just Faraday and Zeitwerk. Because working with AI should be a joy, not a chore.

## Features

- 💬 **Chat** with OpenAI, Anthropic, Gemini, and DeepSeek models
- 👁️ **Vision and Audio** understanding
- 📄 **PDF Analysis** for analyzing documents
- 🖼️ **Image generation** with DALL-E and other providers
- 📊 **Embeddings** for vector search and semantic analysis
- 🔧 **Tools** that let AI use your Ruby code
- 🚂 **Rails integration** to persist chats and messages with ActiveRecord
- 🌊 **Streaming** responses with proper Ruby patterns

## What makes it great

```ruby
# Just ask questions
chat = RubyLLM.chat
chat.ask "What's the best way to learn Ruby?"

# Analyze images
chat.ask "What's in this image?", with: { image: "ruby_conf.jpg" }

# Analyze audio recordings
chat.ask "Describe this meeting", with: { audio: "meeting.wav" }

# Analyze documents
chat.ask "Summarize this document", with: { pdf: "contract.pdf" }

# Stream responses in real-time
chat.ask "Tell me a story about a Ruby programmer" do |chunk|
  print chunk.content
end

# Generate images
RubyLLM.paint "a sunset over mountains in watercolor style"

# Create vector embeddings
RubyLLM.embed "Ruby is elegant and expressive"

# Let AI use your code
class Weather < RubyLLM::Tool
  description "Gets current weather for a location"
  param :latitude, desc: "Latitude (e.g., 52.5200)"
  param :longitude, desc: "Longitude (e.g., 13.4050)"

  def execute(latitude:, longitude:)
    url = "https://api.open-meteo.com/v1/forecast?latitude=#{latitude}&longitude=#{longitude}&current=temperature_2m,wind_speed_10m"

    response = Faraday.get(url)
    data = JSON.parse(response.body)
  rescue => e
    { error: e.message }
  end
end

chat.with_tool(Weather).ask "What's the weather in Berlin? (52.5200, 13.4050)"
```

## Installation

```ruby
# In your Gemfile
gem 'ruby_llm'

# Then run
bundle install

# Or install it yourself
gem install ruby_llm
```

Configure with your API keys:

```ruby
RubyLLM.configure do |config|
  config.openai_api_key = ENV['OPENAI_API_KEY']
  config.anthropic_api_key = ENV['ANTHROPIC_API_KEY']
  config.gemini_api_key = ENV['GEMINI_API_KEY']
  config.deepseek_api_key = ENV['DEEPSEEK_API_KEY']
end
```

## Have great conversations

```ruby
# Start a chat with the default model (GPT-4o-mini)
chat = RubyLLM.chat

# Or specify what you want
chat = RubyLLM.chat(model: 'claude-3-7-sonnet-20250219')

# Simple questions just work
chat.ask "What's the difference between attr_reader and attr_accessor?"

# Multi-turn conversations are seamless
chat.ask "Could you give me an example?"

# Stream responses in real-time
chat.ask "Tell me a story about a Ruby programmer" do |chunk|
  print chunk.content
end

# Understand content in multiple forms
chat.ask "Compare these diagrams", with: { image: ["diagram1.png", "diagram2.png"] }
chat.ask "Summarize this document", with: { pdf: "contract.pdf" }
chat.ask "What's being said?", with: { audio: "meeting.wav" }

# Need a different model mid-conversation? No problem
chat.with_model('gemini-2.0-flash').ask "What's your favorite algorithm?"
```

## Rails integration that makes sense

```ruby
# app/models/chat.rb
class Chat < ApplicationRecord
  acts_as_chat

  # Works great with Turbo
  broadcasts_to ->(chat) { "chat_#{chat.id}" }
end

# app/models/message.rb
class Message < ApplicationRecord
  acts_as_message
end

# app/models/tool_call.rb
class ToolCall < ApplicationRecord
  acts_as_tool_call
end

# In your controller
chat = Chat.create!(model_id: "gpt-4o-mini")
chat.ask("What's your favorite Ruby gem?") do |chunk|
  Turbo::StreamsChannel.broadcast_append_to(
    chat,
    target: "response",
    partial: "messages/chunk",
    locals: { chunk: chunk }
  )
end

# That's it - chat history is automatically saved
```

## Creating tools is a breeze

```ruby
class Search < RubyLLM::Tool
  description "Searches a knowledge base"

  param :query, desc: "The search query"
  param :limit, type: :integer, desc: "Max results", required: false

  def execute(query:, limit: 5)
    # Your search logic here
    Document.search(query).limit(limit).map(&:title)
  end
end

# Let the AI use it
chat.with_tool(Search).ask "Find documents about Ruby 3.3 features"
```

## Learn more

Check out the guides at https://rubyllm.com for deeper dives into conversations with tools, streaming responses, embedding generations, and more.

## Contributing

We welcome contributions to RubyLLM!

See [CONTRIBUTING.md](CONTRIBUTING.md) for detailed instructions on how to:
- Run the test suite
- Add new features
- Update documentation
- Re-record VCR cassettes when needed

We appreciate your help making RubyLLM better!

## License

Released under the MIT License.

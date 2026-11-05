{% if site.docs_unreleased %}These docs cover unreleased RubyLLM from `main`.{% else %}These docs cover RubyLLM {{ site.gem_version }}.{% endif %} RubyLLM is the Ruby AI framework: chats, tools, agents, MCP, structured output, evaluations, images, video, audio, OCR, embeddings, reranking, and Rails integration behind one API across {{ site.provider_count }} providers.

## Quick Reference

```ruby
# Install: bundle add ruby_llm
RubyLLM.configure do |config|
  config.openai_api_key = ENV["OPENAI_API_KEY"]
end

# Chat
chat = RubyLLM.chat
chat.with_instructions("Answer in one sentence.").ask "What is Ruby?"
chat.ask "What's in this image?", with: "photo.jpg"

# Tool: parameters come from the keyword arguments of execute
class Weather < RubyLLM::Tool
  description "Gets current weather for a location"

  def execute(latitude:, longitude:)
    WeatherService.current(latitude:, longitude:)
  end
end

chat.with_tools(Weather).ask "Should I bike to work in Berlin today?"

# Agent: reusable instructions, tools, and options
class SupportAgent < RubyLLM::Agent
  instructions "Accept returns of unopened items within 30 days."
  tools Weather
end

SupportAgent.new.ask "Can I return an unopened item after 14 days?"

# Rails: bin/rails generate ruby_llm:install && bin/rails db:migrate
class Chat < ApplicationRecord
  acts_as_chat
end

Chat.create!(model: "{{ site.models.default_chat }}").ask "Hello"
```

- Check the installed version with `RubyLLM::VERSION`. The root docs cover the latest release, `/next/` covers `main`, and `/v1/` covers 1.x.
- Use `instructions`, never `system_prompt`. Use `max_output_tokens`, not `max_tokens`, and `thinking`, not `reasoning`.
- Every `with_*` method returns the chat, so calls chain. Pass `provider:` as a keyword. Keep `provider_options` for fields only one provider has.
- Read structured output with `message.parsed`, tokens with `message.tokens`, and cost with `message.cost`. An unknown cost is `nil`.
- Verify model IDs with `RubyLLM.models.find(id)` instead of guessing them.

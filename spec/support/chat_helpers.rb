# frozen_string_literal: true

module ChatHelpers
  def basic_chat(model:, provider:, temperature: nil)
    chat = RubyLLM.chat(model: model, provider: provider)
    chat = chat.with_temperature(temperature) if temperature
    chat
  end
end

RSpec.configure do |config|
  config.include ChatHelpers
end

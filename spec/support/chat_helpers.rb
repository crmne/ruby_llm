# frozen_string_literal: true

module ChatHelpers
  # gpustack/qwen3 leaks thinking tags into content unless thinking is disabled.
  def basic_chat(model:, provider:, temperature: nil)
    chat = RubyLLM.chat(model: model, provider: provider)
    chat = chat.with_temperature(temperature) if temperature
    chat = chat.with_provider_options(enable_thinking: false) if provider == :gpustack && model == 'qwen3'
    chat
  end
end

RSpec.configure do |config|
  config.include ChatHelpers
end

# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Chat do
  include_context 'with configured RubyLLM'

  {
    'Chat Completions' => { provider: :deepseek },
    'Chat Completions on Cohere' => { provider: :cohere },
    'Responses' => { provider: :openai },
    'Anthropic' => { provider: :anthropic },
    'Gemini' => { provider: :gemini },
    'Interactions' => { provider: :gemini, purpose: :mcp, protocol: :interactions },
    'Converse' => { provider: :bedrock },
    'Mistral Conversations' => { provider: :mistral, protocol: :conversations }
  }.each do |family, options|
    it "sends tool results followed by two queued user messages without problems on #{family}" do
      provider, purpose, protocol = options.values_at(:provider, :purpose, :protocol)
      model = purpose ? model_for(provider, purpose) : model_for(provider)
      chat = secret_chat(provider:, model:, protocol:)
      chat.messages.pop(2)
      chat.queue('secret steer')
      chat.queue('secret later', steer: false)
      chat.take_queued_messages

      shape = refused_request_shape(chat)
      queued_parts = shape.turns.flat_map(&:parts).last(2)

      expect(shape.problems).to be_empty
      expect(shape.tool_rounds.map(&:paired?)).to eq([true])
      expect(queued_parts.map { |part| [part.kind, part.size] }).to eq([[:text, 12], [:text, 12]])
      expect_no_secrets(shape)
    end
  end
end

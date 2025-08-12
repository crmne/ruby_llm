# frozen_string_literal: true

RSpec.describe RubyLLM::Chat do
  context 'with failover' do
    include_context 'with configured RubyLLM'

    it 'fails over to the next provider when the first one fails' do
      chat = RubyLLM.chat(provider: :anthropic, model: 'claude-3-7-sonnet')
      chat.with_failover({ provider: :bedrock, model: 'claude-3-7-sonnet' })

      chat.ask "#{MASSIVE_TEXT_FOR_RATE_LIMIT_TEST} What is the capital of France?"

      chat.ask 'What is the capital of Germany?'
      chat.ask 'What is the capital of Italy?'
      response = chat.ask 'What is the capital of England?'

      expect(response.content).to include('London')
    end

    it 'has a list of models to failover to' do
      chat = RubyLLM.chat(provider: :anthropic, model: 'claude-3-7-sonnet')
      chat.with_failover({ provider: :bedrock, model: 'claude-3-7-sonnet' }, "gpt-5")

      expected_failover_configurations = [
        { provider: :bedrock, model: 'claude-3-7-sonnet' },
        { provider: :openai, model: 'gpt-5' }
      ]
      expect(chat.instance_variable_get(:@failover_configurations)).to eq(expected_failover_configurations)
    end
  end
end

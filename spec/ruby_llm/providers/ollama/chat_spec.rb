# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::Ollama::Chat do
  describe '.render_payload' do
    let(:provider) { RubyLLM::Providers::Ollama::ChatCompletions.allocate }
    let(:messages) { [RubyLLM::Message.new(role: :user, content: 'Hello')] }

    def render_payload(thinking: nil)
      model = instance_double(RubyLLM::Model, id: 'qwen3')

      provider.send(
        :render_payload,
        messages,
        tools: {},
        temperature: nil,
        model: model,
        stream: false,
        thinking: thinking
      )
    end

    %w[low medium high max none].each do |effort|
      it "passes #{effort} effort through as reasoning_effort" do
        payload = render_payload(thinking: RubyLLM::Thinking::Config.new(effort: effort.to_sym))

        expect(payload[:reasoning_effort]).to eq(effort)
      end
    end

    it 'ignores thinking budgets with a debug note' do
      allow(RubyLLM.logger).to receive(:debug)

      payload = render_payload(thinking: RubyLLM::Thinking::Config.new(budget: 4096))

      expect(payload).not_to have_key(:reasoning_effort)
      expect(RubyLLM.logger).to have_received(:debug)
    end
  end

  describe '.format_messages' do
    it 'includes empty content when replaying a thinking-only assistant message' do
      thinking = RubyLLM::Thinking.new(text: 'I should reason first')
      message = RubyLLM::Message.new(role: :assistant, content: nil, thinking: thinking)
      provider = RubyLLM::Providers::Ollama::ChatCompletions.allocate

      formatted = provider.send(:format_messages, [message])

      expect(formatted.first[:content]).to eq('')
      expect(formatted.first[:reasoning_content]).to eq('I should reason first')
    end
  end
end

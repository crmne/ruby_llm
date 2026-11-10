# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::GPUStack::Chat do
  let(:context) do
    RubyLLM.context do |config|
      config.gpustack_api_base = 'https://gpu.example.test/v1'
      config.gpustack_api_key = 'isolated-key'
    end
  end
  let(:chat) { context.chat(model: model_for(:gpustack), provider: :gpustack) }

  describe '#with_compaction' do
    it 'keeps the last tokens up to the threshold' do
      payload = chat.with_compaction(at: 500).ask_later('Hello').render

      expect(payload).to include(truncate_prompt_tokens: 500, truncation_side: 'left')
    end

    it 'uses the longest prompt the model allows with no threshold' do
      payload = chat.with_compaction.ask_later('Hello').render

      expect(payload).to include(truncate_prompt_tokens: -1, truncation_side: 'left')
    end

    it 'logs the options vLLM cannot apply and does not send them' do
      allow(RubyLLM.logger).to receive(:debug)

      payload = chat.with_compaction(at: 500, instructions: 'Keep decisions.', pause_after: true)
                    .ask_later('Hello').render

      expect(RubyLLM.logger).to have_received(:debug) { |&block| expect(block.call).to include('instructions') }
      expect(payload.keys).not_to include(:instructions, :pause_after)
    end

    it 'sends nothing without compaction' do
      expect(chat.ask_later('Hello').render.keys).not_to include(:truncate_prompt_tokens, :truncation_side)
    end
  end
end

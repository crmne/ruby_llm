# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Chat do
  let(:provider_class) do
    Class.new(RubyLLM::Provider) do
      self.slug = 'custom'
      protocol :chat_completions, RubyLLM::Protocols::ChatCompletions

      def api_base = 'https://custom.example/v1'
      def headers = {}
    end
  end
  let(:model) do
    RubyLLM::Model.new(
      id: 'z-ai/glm-5.3-flash', provider: 'custom',
      pricing: { text_tokens: { standard: { input_per_million: 0.2, output_per_million: 0.5 } } }
    )
  end
  let(:other_model) do
    RubyLLM::Model.new(
      id: model.id, provider: 'openrouter',
      pricing: { text_tokens: { standard: { input_per_million: 0.075, output_per_million: 0.25 } } }
    )
  end

  before do
    RubyLLM::Provider.register(:custom, provider_class)
    allow(RubyLLM::Models).to receive(:instance).and_return(RubyLLM::Models.new([model, other_model]))
  end

  after do
    RubyLLM::Provider.unregister(:custom)
  end

  [false, true].each do |streaming|
    it "uses the custom provider's prices with streaming #{streaming}" do
      message_key = streaming ? :delta : :message
      body = {
        model: model.id,
        choices: [{ index: 0, message_key => { role: 'assistant', content: 'ok' }, finish_reason: 'stop' }],
        usage: { prompt_tokens: 19, completion_tokens: 17, total_tokens: 36 }
      }.to_json
      body = "data: #{body}\n\ndata: [DONE]\n\n" if streaming
      content_type = streaming ? 'text/event-stream' : 'application/json'
      stub_request(:post, 'https://custom.example/v1/chat/completions')
        .to_return(body: body, headers: { 'Content-Type' => content_type })
      chat = described_class.new(model: model.id, provider: :custom, protocol: :chat_completions)

      response = if streaming
                   chat.ask('Reply with ok') { |chunk| expect(chunk.content).to eq('ok') }
                 else
                   chat.ask('Reply with ok')
                 end

      expect(response.content).to eq('ok')
      expect(response.model_info).to eq(model)
      expect(response.cost.input).to be_within(1e-12).of(0.0000038)
      expect(response.cost.output).to be_within(1e-12).of(0.0000085)
      expect(response.cost.total).to be_within(1e-12).of(0.0000123)
      expect(chat.cost.total).to eq(response.cost.total)
      expect(chat.usage_entries).to contain_exactly(
        have_attributes(provider: 'custom', model: model.id, cost: have_attributes(total: response.cost.total))
      )
    end
  end
end

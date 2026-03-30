# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::OpenAI do
  include_context 'with configured RubyLLM'

  subject(:provider) { described_class.new(RubyLLM.config) }

  describe '#complete' do
    let(:model) { instance_double(RubyLLM::Model::Info, id: 'gpt-4o') }
    let(:response) { instance_double(Faraday::Response) }

    before do
      allow(provider.connection).to receive(:post).and_return(response)
      allow(provider).to receive(:parse_completion_response).with(response).and_return(
        RubyLLM::Message.new(role: :assistant, content: 'ok')
      )
    end

    it 'adds max_completion_tokens when max_tokens is provided' do
      provider.complete(
        [],
        tools: {},
        temperature: nil,
        model: model,
        params: { max_tokens: 128 },
        headers: {}
      )

      expect(provider.connection).to have_received(:post).with(
        'chat/completions',
        hash_including(max_tokens: 128, max_completion_tokens: 128)
      )
    end
  end

  describe '#normalize_params' do
    it 'preserves an explicit max_completion_tokens value' do
      normalized = provider.send(:normalize_params, max_tokens: 128, max_completion_tokens: 64)

      expect(normalized).to include(max_tokens: 128, max_completion_tokens: 64)
    end
  end
end
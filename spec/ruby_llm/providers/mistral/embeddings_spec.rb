# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::Mistral::Embeddings do
  let(:config) do
    RubyLLM::Configuration.new.tap { |configuration| configuration.mistral_api_key = 'test' }
  end
  let(:provider) { RubyLLM::Providers::Mistral.new(config) }
  let(:protocol) do
    RubyLLM::Providers::Mistral.protocols.fetch(:chat_completions).allocate.tap do |instance|
      instance.instance_variable_set(:@provider, provider)
    end
  end

  describe '#parse_embedding_response' do
    it 'pairs each vector with the input its row index names' do
      body = {
        'data' => [{ 'index' => 1, 'embedding' => [0.2] }, { 'index' => 0, 'embedding' => [0.1] }],
        'usage' => { 'prompt_tokens' => 8 }
      }

      embedding = protocol.send(:parse_embedding_response, Struct.new(:body).new(body),
                                model: 'mistral-embed', text: %w[Ruby Python])

      expect(embedding.vectors).to eq([[0.1], [0.2]])
      expect(embedding.tokens.input).to eq(8)
    end
  end
end

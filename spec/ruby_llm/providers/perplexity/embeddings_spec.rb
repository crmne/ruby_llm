# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::Perplexity::Embeddings do
  let(:config) do
    RubyLLM::Configuration.new.tap { |configuration| configuration.perplexity_api_key = 'test' }
  end
  let(:provider) { RubyLLM::Providers::Perplexity.new(config) }
  let(:protocol) do
    RubyLLM::Providers::Perplexity.protocols.fetch(:chat_completions).allocate.tap do |instance|
      instance.instance_variable_set(:@provider, provider)
    end
  end

  describe '#parse_embedding_response' do
    it 'pairs each vector with the input its row index names' do
      body = {
        'data' => [
          { 'index' => 1, 'embedding' => Base64.strict_encode64([2, -2].pack('c*')) },
          { 'index' => 0, 'embedding' => Base64.strict_encode64([1, -1].pack('c*')) }
        ],
        'usage' => { 'prompt_tokens' => 8 }
      }

      embedding = protocol.send(:parse_embedding_response, Struct.new(:body).new(body),
                                model: 'pplx-embed-v1-0.6b', text: %w[Ruby Python])

      expect(embedding.vectors).to eq([[1, -1], [2, -2]])
    end
  end
end

# frozen_string_literal: true

require 'spec_helper'

# Fixtures follow the response example published at
# https://docs.cohere.com/reference/list-models.
RSpec.describe RubyLLM::Protocols::Cohere::Models do
  let(:protocol) { Object.new.extend(described_class) }

  let(:body) do
    {
      'models' => [
        {
          'name' => 'command-a-plus-05-2026',
          'is_deprecated' => false,
          'endpoints' => %w[chat],
          'finetuned' => false,
          'context_length' => 128_000,
          'tokenizer_url' => 'https://cohere.com/tokenizer/command-a-plus-05-2026.json',
          'default_endpoints' => ['chat'],
          'features' => %w[json_mode json_schema tools tool_choice citations]
        },
        {
          'name' => 'embed-v4.0',
          'is_deprecated' => false,
          'endpoints' => ['embed'],
          'context_length' => 128_000
        },
        {
          'name' => 'command-r-03-2024',
          'is_deprecated' => true,
          'endpoints' => ['chat']
        }
      ],
      'next_page_token' => 'next-page'
    }
  end

  def parse
    protocol.send(:parse_list_models_response, instance_double(Faraday::Response, body: body), 'cohere')
  end

  describe '#models_url' do
    # The model catalog is the one Cohere endpoint still served from v1.
    it 'reads the v1 catalog in a single page' do
      expect(protocol.send(:models_url)).to eq('v1/models?page_size=1000')
    end
  end

  describe '#parse_list_models_response' do
    it 'skips deprecated models' do
      expect(parse.map(&:id)).to eq(%w[command-a-plus-05-2026 embed-v4.0])
    end

    it 'maps a chat model' do
      model = parse.first

      expect(model).to have_attributes(
        id: 'command-a-plus-05-2026',
        provider: 'cohere',
        family: nil,
        context_window: 128_000,
        max_output_tokens: nil
      )
      expect(model.capabilities).to contain_exactly(
        'streaming', 'function_calling', 'tool_choice', 'structured_output', 'json_mode', 'citations'
      )
      expect(model.modalities.input).to eq(['text'])
    end

    it 'maps an embedding model' do
      model = parse.last

      expect(model.modalities.output).to eq(['embeddings'])
      expect(model.capabilities).to be_empty
    end

    it 'uses the exact endpoint variants Cohere reports' do
      expect(protocol.send(:modalities_from, ['embed_image'])).to eq(input: ['image'], output: ['embeddings'])
      expect(protocol.send(:modalities_from, ['transcriptions'])).to eq(input: ['audio'], output: ['text'])
      expect(protocol.send(:capabilities_from, ['transcriptions'], nil)).to eq(['transcription'])
    end

    it 'keeps the Cohere endpoint list in metadata' do
      expect(parse.first.metadata).to include(
        endpoints: ['chat'],
        features: %w[json_mode json_schema tools tool_choice citations],
        tokenizer_url: 'https://cohere.com/tokenizer/command-a-plus-05-2026.json'
      )
    end

    it 'does not fill metadata the provider omits' do
      expect(parse.first.created_at).to be_nil
      expect(parse.first.pricing.to_h).to be_empty
    end
  end
end

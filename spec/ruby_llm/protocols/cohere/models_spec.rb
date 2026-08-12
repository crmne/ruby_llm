# frozen_string_literal: true

require 'spec_helper'

# Fixtures follow the response example published at
# https://docs.cohere.com/reference/list-models.
RSpec.describe RubyLLM::Protocols::Cohere::Models do
  let(:protocol) { Object.new.extend(described_class) }
  let(:capabilities) { RubyLLM::Providers::Cohere::Capabilities }

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
          'features' => %w[json_schema tools]
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
    protocol.send(:parse_list_models_response, instance_double(Faraday::Response, body: body), 'cohere', capabilities)
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
        family: 'command-a-plus',
        context_window: 128_000,
        max_output_tokens: 64_000
      )
      expect(model.capabilities).to include('streaming', 'function_calling', 'citations', 'vision', 'reasoning')
      expect(model.modalities.input).to include('text', 'image')
    end

    it 'maps an embedding model' do
      model = parse.last

      expect(model.modalities.output).to eq(['embeddings'])
      expect(model.capabilities).to be_empty
    end

    it 'keeps the Cohere endpoint list in metadata' do
      expect(parse.first.metadata).to include(
        endpoints: ['chat'],
        features: %w[json_schema tools],
        tokenizer_url: 'https://cohere.com/tokenizer/command-a-plus-05-2026.json'
      )
    end

    it 'dates models from the published release dates' do
      expect(parse.first.created_at).to eq(Time.parse('2026-05-20'))
    end
  end
end

# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Protocols::Gemini::Models do
  describe '#parse_list_models_response' do
    let(:parser) { Object.new.extend(described_class) }
    let(:response_class) { Struct.new(:body) }

    let(:response) do
      instance_double(
        response_class,
        body: {
          'models' => [
            {
              'name' => 'models/gemini-2.0-flash-001',
              'displayName' => 'Gemini 2.0 Flash',
              'version' => '001',
              'description' => 'Fast Gemini model',
              'supportedGenerationMethods' => ['generateContent']
            }
          ]
        }
      )
    end

    it 'keeps only metadata the provider reports' do
      model = parser.send(:parse_list_models_response, response, 'gemini').first

      expect(model.id).to eq('gemini-2.0-flash-001')
      expect(model.name).to eq('Gemini 2.0 Flash')
      expect(model.provider).to eq('gemini')
      expect(model.family).to be_nil
      expect(model.context_window).to be_nil
      expect(model.max_output_tokens).to be_nil
      expect(model.capabilities).to be_empty
      expect(model.pricing.to_h).to be_empty
      expect(model.metadata).to eq(
        version: '001',
        description: 'Fast Gemini model',
        supported_generation_methods: ['generateContent']
      )
    end

    it 'maps the operations reported by the provider' do
      operations = %w[embedContent asyncBatchEmbedContent createCachedContent bidiGenerateContent]
      operation_response = instance_double(
        response_class,
        body: {
          'models' => [{ 'name' => 'models/gemini-embedding-test', 'supportedGenerationMethods' => operations }]
        }
      )

      model = parser.send(:parse_list_models_response, operation_response, 'gemini').first

      expect(model.type).to eq('embedding')
      expect(model.modalities.to_h).to eq(input: ['text'], output: ['embeddings'])
      expect(model.capabilities).to contain_exactly('batch', 'caching', 'streaming', 'realtime')
    end
  end
end

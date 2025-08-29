# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Models do
  include_context 'with configured RubyLLM'

  describe 'models.json structure validation' do
    let(:models_json_path) { described_class.models_file }
    let(:models_data) { JSON.parse(File.read(models_json_path)) }

    it 'validates models.json has correct structure' do
      expect(models_data).to be_an(Array)
      expect(models_data).not_to be_empty

      models_data.each do |model|
        # Required fields
        expect(model).to have_key('id')
        expect(model['id']).to be_a(String)

        expect(model).to have_key('name')
        expect(model['name']).to be_a(String)

        expect(model).to have_key('provider')
        expect(model['provider']).to be_a(String)

        # Optional fields with type validation
        expect(model['family']).to be_a(String).or be_nil if model.key?('family')

        expect(model['created_at']).to be_a(String).or be_nil if model.key?('created_at')

        expect(model['context_window']).to be_a(Integer).or be_nil if model.key?('context_window')

        expect(model['max_output_tokens']).to be_a(Integer).or be_nil if model.key?('max_output_tokens')

        expect(model['knowledge_cutoff']).to be_a(String).or be_nil if model.key?('knowledge_cutoff')

        if model.key?('modalities')
          expect(model['modalities']).to be_a(Hash)
          if model['modalities'].key?('input')
            expect(model['modalities']['input']).to be_an(Array)
            expect(model['modalities']['input']).to all(be_a(String))
          end
          if model['modalities'].key?('output')
            expect(model['modalities']['output']).to be_an(Array)
            expect(model['modalities']['output']).to all(be_a(String))
          end
        end

        if model.key?('capabilities')
          expect(model['capabilities']).to be_an(Array)
          expect(model['capabilities']).to all(be_a(String))
        end

        expect(model['pricing']).to be_a(Hash) if model.key?('pricing')

        expect(model['metadata']).to be_a(Hash) if model.key?('metadata')
      end
    end

    it 'ensures all models have capabilities as an array' do
      models_data.each do |model|
        expect(model['capabilities']).to be_an(Array),
                                         "Model #{model['id']} (#{model['provider']}) has capabilities as " \
                                         "#{model['capabilities'].class} instead of Array"
      end
    end

    it 'ensures no provider has models with mixed capability types' do
      providers_with_issues = {}

      models_data.group_by { |m| m['provider'] }.each do |provider, models|
        capability_types = models.map { |m| m['capabilities'].class }.uniq
        providers_with_issues[provider] = capability_types if capability_types.size > 1
      end

      expect(providers_with_issues).to be_empty,
                                       "Providers with mixed capability types: #{providers_with_issues}"
    end
  end

  describe 'refresh models output structure' do
    before do
      # Mock the API responses to ensure consistent test results
      allow(described_class).to receive_messages(fetch_from_providers: mock_provider_models, fetch_from_parsera: [])
    end

    let(:mock_provider_models) do
      [
        RubyLLM::Model::Info.new(
          id: 'test-model-1',
          name: 'Test Model 1',
          provider: 'openai',
          capabilities: %w[chat streaming function_calling],
          modalities: { input: %w[text], output: %w[text] }
        ),
        RubyLLM::Model::Info.new(
          id: 'test-model-2',
          name: 'Test Model 2',
          provider: 'anthropic',
          capabilities: %w[chat streaming],
          modalities: { input: %w[text image], output: %w[text] }
        )
      ]
    end

    it 'returns models with consistent structure' do
      models = described_class.refresh!

      expect(models).to be_a(described_class)
      expect(models.all).to all(be_a(RubyLLM::Model::Info))

      models.all.each do |model|
        expect(model.capabilities).to be_an(Array)
        expect(model.modalities).to be_a(RubyLLM::Model::Modalities)
        expect(model.pricing).to be_a(RubyLLM::Model::Pricing)
      end
    end

    it 'saves models with correct JSON structure' do
      models = described_class.refresh!

      # Create a temporary file for testing
      temp_file = Tempfile.new(['test_models', '.json'])
      allow(described_class).to receive(:models_file).and_return(temp_file.path)

      models.save_to_json

      saved_data = JSON.parse(File.read(temp_file.path))
      expect(saved_data).to be_an(Array)

      saved_data.each do |model_data|
        expect(model_data['capabilities']).to be_an(Array)
        expect(model_data['modalities']).to be_a(Hash)
        expect(model_data['pricing']).to be_a(Hash)
      end

      temp_file.unlink
    end
  end

  describe 'Model::Info capabilities handling' do
    context 'when capabilities is an array' do
      let(:model) do
        RubyLLM::Model::Info.new(
          id: 'test-model',
          name: 'Test Model',
          provider: 'test',
          capabilities: %w[chat streaming function_calling]
        )
      end

      it 'stores capabilities as an array' do
        expect(model.capabilities).to eq(%w[chat streaming function_calling])
      end

      it 'supports capability checking' do
        expect(model.supports?('chat')).to be true
        expect(model.supports?('streaming')).to be true
        expect(model.supports?('function_calling')).to be true
        expect(model.supports?('vision')).to be false
      end

      it 'includes capabilities as array in to_h' do
        hash = model.to_h
        expect(hash[:capabilities]).to eq(%w[chat streaming function_calling])
      end
    end

    context 'when capabilities is accidentally a hash (bug scenario)' do
      it 'handles hash capabilities gracefully' do
        # This test documents the current behavior with hash capabilities
        # The Model::Info class expects an array, so passing a hash should either:
        # 1. Be converted to an array
        # 2. Raise an error
        # 3. Be handled gracefully

        expect do
          RubyLLM::Model::Info.new(
            id: 'test-model',
            name: 'Test Model',
            provider: 'test',
            capabilities: { chat: true, streaming: true }
          )
        end.not_to raise_error
      end
    end
  end
end

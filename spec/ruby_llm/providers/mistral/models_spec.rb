# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::Mistral::Models do
  subject(:model) { described_class.parse_list_models_response(response, 'mistral', capabilities).first }

  let(:capabilities) do
    Class.new do
      def release_date_for(_model_id) = '2025-01-02'
      def format_display_name(_model_id) = 'Mistral Test'
      def model_family(_model_id) = 'mistral'
      def context_window_for(_model_id) = 128_000
      def max_tokens_for(_model_id) = 4096
      def modalities_for(_model_id) = { input: ['text'], output: ['text'] }
      def capabilities_for(_model_id) = %w[streaming vision]
      def pricing_for(_model_id) = {}
    end.new
  end
  let(:model_data) do
    {
      'id' => 'mistral-test',
      'object' => 'model',
      'owned_by' => 'mistralai',
      'description' => 'A test model',
      'max_context_length' => 262_144,
      'aliases' => ['mistral-test-latest'],
      'deprecation' => '2026-08-31T12:00:00Z',
      'deprecation_replacement_model' => 'mistral-medium-3-5',
      'capabilities' => {
        'completion_chat' => true,
        'function_calling' => true,
        'vision' => false,
        'audio_speech' => true
      }
    }
  end
  let(:response) { Struct.new(:body).new({ 'data' => [model_data] }) }

  describe '.parse_list_models_response' do
    it 'parses release dates without depending on global requires' do
      expect(model.id).to eq('mistral-test')
      expect(model.created_at).to be_a(Time)
    end

    it 'takes the context window the listing reports' do
      expect(model.context_window).to eq(262_144)
      expect(model.max_output_tokens).to eq(4096)
    end

    it 'adds the capabilities the listing reports and drops the ones it denies' do
      expect(model.capabilities).to contain_exactly('streaming', 'function_calling', 'speech_generation')
    end

    it 'gives image input to the models the listing marks as vision' do
      model_data['capabilities']['vision'] = true

      expect(model.modalities.input).to eq(%w[text image])
      expect(model.capabilities).to include('vision')
    end

    it 'keeps the deprecation, description and aliases in metadata' do
      expect(model.metadata).to include(
        description: 'A test model',
        aliases: ['mistral-test-latest'],
        deprecation: '2026-08-31T12:00:00Z',
        deprecation_replacement_model: 'mistral-medium-3-5'
      )
    end

    it 'falls back to the capability table for what the listing omits' do
      model_data.delete('max_context_length')
      model_data.delete('capabilities')
      model_data.delete('deprecation')
      model_data['aliases'] = []

      expect(model.context_window).to eq(128_000)
      expect(model.capabilities).to eq(%w[streaming vision])
      expect(model.metadata.keys).not_to include(:deprecation, :aliases)
    end

    context 'without a capability table' do
      let(:capabilities) { nil }

      it 'builds models from the listing alone' do
        expect(model.name).to eq('mistral-test')
        expect(model.context_window).to eq(262_144)
        expect(model.capabilities).to contain_exactly('function_calling', 'speech_generation')
        expect(model.modalities.to_h).to eq(input: ['text'], output: ['text'])
      end
    end
  end
end

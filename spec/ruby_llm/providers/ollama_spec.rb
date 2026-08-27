# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::Ollama do
  include_context 'with configured RubyLLM'

  describe '#headers' do
    it 'returns empty headers when no API key is configured' do
      RubyLLM.configure { |config| config.ollama_api_key = nil }
      provider = described_class.new(RubyLLM.config)

      expect(provider.headers).to eq({})
    end

    it 'returns Authorization header when API key is configured' do
      RubyLLM.configure { |config| config.ollama_api_key = 'test-ollama-key' }
      provider = described_class.new(RubyLLM.config)

      expect(provider.headers).to eq({ 'Authorization' => 'Bearer test-ollama-key' })
    end
  end

  describe 'model listing' do
    let(:protocol) { described_class::ChatCompletions.allocate }

    def response_for(*ids)
      instance_double(Faraday::Response, body: { 'data' => ids.map { |id| { 'id' => id } } })
    end

    it 'derives capabilities and modalities from what /api/show reports' do
      models = protocol.parse_list_models_response(
        response_for('llava:7b', 'qwen3:8b'), 'ollama',
        details: { 'llava:7b' => %w[completion vision], 'qwen3:8b' => %w[completion tools thinking] }
      )

      vision, text = models
      expect(vision.capabilities).to eq(%w[streaming structured_output vision])
      expect(vision.modalities.input).to eq(%w[text image])
      expect(text.capabilities).to eq(%w[streaming structured_output function_calling reasoning])
      expect(text.modalities.input).to eq(%w[text])
      expect(text.supports?(:vision)).to be(false)
    end

    it 'claims nothing beyond the server defaults when /api/show says nothing' do
      model = protocol.parse_list_models_response(response_for('mystery:latest'), 'ollama').first

      expect(model.capabilities).to eq(%w[streaming structured_output])
      expect(model.modalities.to_h).to eq(input: %w[text], output: %w[text])
    end

    it 'reads embedding models as embedding models' do
      models = protocol.parse_list_models_response(
        response_for('nomic-embed-text'), 'ollama', details: { 'nomic-embed-text' => %w[embedding] }
      )

      expect(models.first.capabilities).to eq([])
      expect(models.first.modalities.to_h).to eq(input: %w[text], output: %w[embeddings])
    end

    it 'asks /api/show about every listed model' do
      provider = described_class.new(RubyLLM.config)
      connection = instance_double(RubyLLM::Connection)
      allow(provider).to receive(:connection).and_return(connection)
      allow(connection).to receive(:get).with('models').and_return(response_for('llava:7b'))
      allow(connection).to receive(:post)
        .with('../api/show', { model: 'llava:7b' })
        .and_return(instance_double(Faraday::Response, body: { 'capabilities' => %w[completion vision] }))

      expect(described_class::ChatCompletions.new(provider).list_models.first.supports?(:vision)).to be(true)
    end

    it 'survives a server that does not answer /api/show' do
      provider = described_class.new(RubyLLM.config)
      connection = instance_double(RubyLLM::Connection)
      allow(provider).to receive(:connection).and_return(connection)
      allow(connection).to receive(:get).with('models').and_return(response_for('llava:7b'))
      allow(connection).to receive(:post).and_raise(RubyLLM::BadRequestError.new(nil, response: nil))

      expect(described_class::ChatCompletions.new(provider).list_models.first.supports?(:vision)).to be(false)
    end
  end
end

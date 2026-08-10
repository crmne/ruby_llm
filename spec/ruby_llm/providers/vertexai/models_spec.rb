# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::VertexAI::Models do
  include_context 'with configured RubyLLM'

  let(:provider) { RubyLLM::Providers::VertexAI.new(RubyLLM.config) }
  let(:catalog) { RubyLLM::Providers::VertexAI::Gemini.new(provider) }

  describe '#determine_model_family' do
    {
      'claude-haiku-4-5' => 'claude-haiku',
      'claude-sonnet-4-5' => 'claude-sonnet',
      'claude-opus-4-5' => 'claude-opus',
      'claude-2' => 'claude',
      'meta/llama-4-maverick-17b-128e-instruct-maas' => 'llama',
      'deepseek-ai/deepseek-v3.1-maas' => 'deepseek',
      'qwen/qwen3-coder-480b-a35b-instruct-maas' => 'qwen',
      'moonshotai/kimi-k2-thinking-maas' => 'kimi',
      'zai-org/glm-4.6-maas' => 'glm',
      'openai/gpt-oss-120b-maas' => 'gpt-oss',
      'google/gemma-3-27b-it' => 'gemma',
      'codestral-2501' => 'codestral',
      'mistral-small-2503' => 'mistral',
      'ministral-3b' => 'mistral',
      'gemini-2.5-flash' => 'gemini-2',
      'gemini-1.5-pro' => 'gemini-1.5',
      'text-embedding-005' => 'text-embedding',
      'chat-bison' => 'palm',
      'imagen-3.0-generate-002' => 'gemini'
    }.each do |model_id, expected|
      it "groups #{model_id} under #{expected}" do
        expect(catalog.send(:determine_model_family, model_id)).to eq(expected)
      end
    end
  end

  describe '#served_directly?' do
    it 'routes Google chat and embedding models by bare name' do
      expect(catalog.send(:served_directly?, 'google', 'gemini-2.5-flash')).to be(true)
      expect(catalog.send(:served_directly?, 'google', 'text-embedding-005')).to be(true)
      expect(catalog.send(:served_directly?, 'google', 'imagegeneration')).to be(false)
    end

    it 'routes every Anthropic model by bare name' do
      expect(catalog.send(:served_directly?, 'anthropic', 'claude-haiku-4-5')).to be(true)
    end

    it 'routes only the known Mistral models' do
      expect(catalog.send(:served_directly?, 'mistralai', 'mistral-small-2503')).to be(true)
      expect(catalog.send(:served_directly?, 'mistralai', 'not-a-mistral')).to be(false)
    end

    it 'ignores publishers served only through the OpenAI-compatible endpoint' do
      expect(catalog.send(:served_directly?, 'meta', 'llama-4-maverick')).to be(false)
    end
  end

  describe '#deployable?' do
    it 'recognizes every deploy action Model Garden exposes' do
      expect(catalog.send(:deployable?, { 'supportedActions' => { 'deploy' => {} } })).to be(true)
      expect(catalog.send(:deployable?, { 'supportedActions' => { 'multiDeployVertex' => {} } })).to be(true)
      expect(catalog.send(:deployable?, { 'supportedActions' => { 'deployGke' => {} } })).to be(true)
    end

    it 'is false for a managed model' do
      expect(catalog.send(:deployable?, {})).to be(false)
    end
  end

  describe '#build_publisher_model' do
    it 'prefixes MaaS models with their publisher' do
      model = catalog.send(
        :build_publisher_model, 'meta', { 'name' => 'publishers/meta/models/llama-4-maverick-maas' }
      )

      expect(model.id).to eq('meta/llama-4-maverick-maas')
      expect(model.family).to eq('llama')
    end

    it 'keeps directly served models on their bare name' do
      model = catalog.send(
        :build_publisher_model, 'anthropic', { 'name' => 'publishers/anthropic/models/claude-haiku-4-5' }
      )

      expect(model.id).to eq('claude-haiku-4-5')
    end

    it 'skips deploy-it-yourself cards' do
      model = catalog.send(
        :build_publisher_model, 'google',
        { 'name' => 'publishers/google/models/gemma-3', 'supportedActions' => { 'deploy' => {} } }
      )

      expect(model).to be_nil
    end

    it 'skips managed models this publisher does not serve by name' do
      model = catalog.send(
        :build_publisher_model, 'meta', { 'name' => 'publishers/meta/models/llama-guard' }
      )

      expect(model).to be_nil
    end
  end

  describe '#extract_capabilities' do
    it 'drops function calling for OCR and embedding models' do
      expect(catalog.send(:extract_capabilities, { 'name' => 'text-embedding-005' })).to eq(%w[streaming])
      expect(catalog.send(:extract_capabilities, { 'name' => 'gemini-2.5-flash' })).to eq(
        %w[streaming function_calling]
      )
    end
  end

  describe '#catalog' do
    it 'pages through the publisher catalog and drops deprecated cards' do
      pages = [
        {
          'publisherModels' => [
            { 'name' => 'publishers/google/models/gemini-2.5-flash' },
            { 'name' => 'publishers/google/models/gemini-1.0-pro', 'launchStage' => 'DEPRECATED' }
          ],
          'nextPageToken' => 'page-2'
        },
        { 'publisherModels' => [{ 'name' => 'publishers/google/models/text-embedding-005' }] }
      ]
      connection = instance_double(RubyLLM::Connection)
      allow(connection).to receive(:get) do |_url, &block|
        request = Struct.new(:headers, :params).new({}, {})
        block&.call(request)
        Struct.new(:body).new(pages.shift)
      end
      catalog.instance_variable_set(:@connection, connection)

      names = catalog.send(:catalog, 'google').map { |data| data['name'] }

      expect(names).to eq(
        ['publishers/google/models/gemini-2.5-flash', 'publishers/google/models/text-embedding-005']
      )
    end

    it 'returns nothing when the catalog request fails' do
      connection = instance_double(RubyLLM::Connection)
      allow(connection).to receive(:get).and_raise(RubyLLM::Error, 'nope')
      allow(RubyLLM.logger).to receive(:debug)
      catalog.instance_variable_set(:@connection, connection)

      expect(catalog.send(:catalog, 'google')).to eq([])
    end
  end

  describe '#list_models' do
    it 'includes the known Google models even when no publisher answers' do
      allow(catalog).to receive(:publisher_models).and_return([])

      models = catalog.list_models

      expect(models.map(&:id)).to include('gemini-2.5-flash', 'text-embedding-005')
      expect(models).to all(have_attributes(provider: 'vertexai'))
      expect(models.first.metadata).to eq(source: 'known_models')
    end
  end
end

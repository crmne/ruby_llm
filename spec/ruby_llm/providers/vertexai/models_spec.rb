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
      expect(catalog.send(:extract_capabilities, 'text-embedding-005')).to eq(%w[streaming])
      expect(catalog.send(:extract_capabilities, 'gemini-2.5-flash')).to eq(%w[streaming function_calling])
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

      names = catalog.send(:catalog, 'google', connection).map { |data| data['name'] }

      expect(names).to eq(
        ['publishers/google/models/gemini-2.5-flash', 'publishers/google/models/text-embedding-005']
      )
    end

    it 'propagates a failed catalog request instead of reporting an empty catalog' do
      connection = instance_double(RubyLLM::Connection)
      allow(connection).to receive(:get).and_raise(RubyLLM::UnauthorizedError, 'nope')

      expect { catalog.send(:catalog, 'google', connection) }.to raise_error(RubyLLM::UnauthorizedError)
    end
  end

  describe 'KNOWN_GOOGLE_MODELS' do
    it 'ships no id that Vertex AI serves in no region' do
      dead = %w[
        gemini-2.0-flash gemini-2.0-flash-exp gemini-1.5-flash gemini-1.5-flash-002
        gemini-1.5-flash-8b gemini-exp-1206 gemini-exp-1121
      ]

      expect(described_class::KNOWN_GOOGLE_MODELS).not_to include(*dead)
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

    it 'raises when every publisher catalog fails rather than passing off the known models as a catalog' do
      allow(catalog).to receive(:publisher_models).and_raise(RubyLLM::UnauthorizedError, 'expired token')

      expect { catalog.list_models }.to raise_error(RubyLLM::Error, /google .*expired token/)
    end

    it 'raises when a single publisher fails, naming every failure' do
      allow(catalog).to receive(:publisher_models).and_return([])
      allow(catalog).to receive(:publisher_models).with('anthropic', anything).and_raise(RubyLLM::ServerError, 'boom')
      allow(catalog).to receive(:publisher_models).with('qwen', anything).and_raise(RubyLLM::ServerError, 'bang')

      expect { catalog.list_models }.to raise_error(RubyLLM::Error, /anthropic .*boom.*qwen .*bang/m)
    end

    it 'lets the live catalog entry win over the known fallback for the same id' do
      allow(catalog).to receive(:publisher_models).and_return([])
      allow(catalog).to receive(:publisher_models).with('google', anything).and_return(
        [catalog.send(:build_model_from_api_data,
                      { 'name' => 'publishers/google/models/gemini-2.5-flash', 'versionId' => '001' },
                      'gemini-2.5-flash')]
      )

      models = catalog.list_models
      flash = models.select { |model| model.id == 'gemini-2.5-flash' }

      expect(flash.size).to eq(1)
      expect(flash.first.metadata[:version_id]).to eq('001')
      expect(models.map(&:id)).to eq(models.map(&:id).uniq)
    end

    it 'keeps embeddings out of function calling in the known fallback too' do
      allow(catalog).to receive(:publisher_models).and_return([])

      embedding = catalog.list_models.find { |model| model.id == 'text-embedding-005' }

      expect(embedding.capabilities).to eq(%w[streaming])
    end
  end

  describe '#catalog_connections' do
    let(:provider) { RubyLLM::Providers::VertexAI.new(vertexai_config('us-east5')) }

    it 'covers the configured location and the supplementary ones' do
      connections = catalog.send(:catalog_connections)

      expect(connections.keys).to eq(%w[us-east5 global us-central1])
      expect(connections['us-east5']).to be(provider.connection)
      expect(connections['global'].connection.url_prefix.host).to eq('aiplatform.googleapis.com')
      expect(connections['us-central1'].connection.url_prefix.host).to eq('us-central1-aiplatform.googleapis.com')
    end

    it 'lists the configured location once when it is already a candidate' do
      allow(provider.config).to receive(:vertexai_location).and_return('us-central1')

      expect(catalog.send(:catalog_connections).keys).to eq(%w[us-central1 global])
    end

    it 'collapses the candidates a custom api base points at the same host' do
      allow(provider.config).to receive(:vertexai_api_base).and_return('https://vertex.example.com/v1beta1')

      expect(catalog.send(:catalog_connections).keys).to eq(%w[us-east5])
    end
  end

  describe '#list_models across locations' do
    subject(:models) { catalog.list_models }

    let(:provider) { RubyLLM::Providers::VertexAI.new(vertexai_config('global')) }
    let(:global_connection) { instance_double(RubyLLM::Connection) }
    let(:central_connection) { instance_double(RubyLLM::Connection) }

    before do
      allow(catalog).to receive_messages(
        catalog_connections: { 'global' => global_connection, 'us-central1' => central_connection },
        publisher_models: []
      )
    end

    def google_models(connection, id, version_id)
      allow(catalog).to receive(:publisher_models).with('google', connection).and_return(
        [catalog.send(:build_model_from_api_data,
                      { 'name' => "publishers/google/models/#{id}", 'versionId' => version_id }, id)]
      )
    end

    it 'unions the catalogs so a model only one location serves survives' do
      google_models(global_connection, 'gemini-2.0-flash-001', '001')
      google_models(central_connection, 'gemini-embedding-001', '001')

      catalogued = models.reject { |model| model.metadata[:source] == 'known_models' }.map(&:id)

      expect(catalogued).to contain_exactly('gemini-2.0-flash-001', 'gemini-embedding-001')
    end

    it 'keeps one entry per id, from the configured location' do
      google_models(global_connection, 'gemini-2.5-flash', 'global-version')
      google_models(central_connection, 'gemini-2.5-flash', 'central-version')

      flash = models.select { |model| model.id == 'gemini-2.5-flash' }

      expect(flash.size).to eq(1)
      expect(flash.first.metadata[:version_id]).to eq('global-version')
    end

    it 'warns and keeps going when a supplementary location fails' do
      allow(RubyLLM.logger).to receive(:warn)
      google_models(global_connection, 'gemini-2.5-flash', '001')
      allow(catalog).to receive(:publisher_models)
        .with('anthropic', central_connection).and_raise(RubyLLM::ServerError, 'boom')

      expect(models.map(&:id)).to include('gemini-2.5-flash')
      expect(RubyLLM.logger).to have_received(:warn).with(/us-central1.*anthropic .*boom/)
    end

    it 'raises when a publisher fails at the configured location' do
      allow(catalog).to receive(:publisher_models)
        .with('anthropic', global_connection).and_raise(RubyLLM::ServerError, 'boom')

      expect { models }.to raise_error(RubyLLM::Error, /Could not fetch the Vertex AI catalog for anthropic .*boom/)
    end
  end

  def vertexai_config(location)
    RubyLLM::Configuration.new.tap do |config|
      config.vertexai_project_id = 'test-project'
      config.vertexai_location = location
    end
  end
end

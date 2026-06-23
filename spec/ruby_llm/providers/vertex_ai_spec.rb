# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::VertexAI do
  subject(:provider) { described_class.new(config) }

  let(:config) do
    instance_double(
      RubyLLM::Configuration,
      request_timeout: 300,
      max_retries: 3,
      retry_interval: 0.1,
      retry_interval_randomness: 0.5,
      retry_backoff_factor: 2,
      http_proxy: nil,
      faraday_adapter: :net_http,
      vertexai_location: location,
      vertexai_project_id: 'test-project',
      vertexai_api_base: vertexai_api_base,
      vertexai_protocol: nil
    )
  end

  let(:vertexai_api_base) { nil }

  describe '#api_base' do
    context 'when location is global' do
      let(:location) { 'global' }

      it 'uses the correct api_base without location prefix' do
        expect(provider.api_base).to eq('https://aiplatform.googleapis.com/v1beta1')
      end
    end

    context 'when location is not global' do
      let(:location) { 'us-central1' }

      it 'uses the correct api_base with location prefix' do
        expect(provider.api_base).to eq('https://us-central1-aiplatform.googleapis.com/v1beta1')
      end
    end

    context 'when vertexai_api_base is set' do
      let(:location) { 'us-central1' }
      let(:vertexai_api_base) { 'https://vertex-proxy.example.com/v1beta1' }

      it 'uses the custom API URL' do
        expect(provider.api_base).to eq('https://vertex-proxy.example.com/v1beta1')
      end
    end
  end

  describe '#render_payload' do
    let(:location) { 'us-central1' }

    it 'formats tool responses with a Vertex AI content role' do
      model = instance_double(RubyLLM::Model::Info, id: 'gemini-3.1-flash-lite-preview')
      messages = [
        RubyLLM::Message.new(role: :user, content: 'What is the weather?'),
        RubyLLM::Message.new(
          role: :assistant,
          content: '',
          tool_calls: {
            'call_1' => RubyLLM::ToolCall.new(id: 'call_1', name: 'weather', arguments: {})
          }
        ),
        RubyLLM::Message.new(role: :tool, content: 'Sunny', tool_call_id: 'call_1')
      ]

      protocol = RubyLLM::Providers::VertexAI::Gemini.new(provider, model)
      payload = protocol.send(:render_payload, messages, tools: {}, temperature: nil, model:)

      expect(payload.dig(:contents, 2, :role)).to eq('user')
      expect(payload.dig(:contents, 2, :parts, 0, :functionResponse, :name)).to eq('weather')
    end
  end

  describe '#protocol_for' do
    let(:location) { 'us-central1' }

    it 'routes claude models to the Anthropic protocol' do
      model = instance_double(RubyLLM::Model::Info, id: 'claude-haiku-4-5')

      expect(provider.protocol_for(model)).to eq(RubyLLM::Providers::VertexAI::Anthropic)
    end

    it 'routes mistral models to the Mistral protocol' do
      %w[mistral-small-2503 ministral-3 codestral-2].each do |id|
        model = instance_double(RubyLLM::Model::Info, id: id)

        expect(provider.protocol_for(model)).to eq(RubyLLM::Providers::VertexAI::Mistral)
      end
    end

    it 'routes publisher-prefixed MaaS models to the Chat Completions protocol' do
      %w[meta/llama-3.3-70b-instruct-maas google/gemma-4-26b-a4b-it-maas].each do |id|
        model = instance_double(RubyLLM::Model::Info, id: id)

        expect(provider.protocol_for(model)).to eq(RubyLLM::Providers::VertexAI::ChatCompletions)
      end
    end

    it 'routes google models to the Gemini protocol' do
      model = instance_double(RubyLLM::Model::Info, id: 'gemini-2.5-flash')

      expect(provider.protocol_for(model)).to eq(RubyLLM::Providers::VertexAI::Gemini)
    end
  end

  describe '#find_batch' do
    let(:location) { 'us-central1' }
    let(:connection) { instance_double(RubyLLM::Connection) }

    before do
      provider.instance_variable_set(:@connection, connection)
    end

    it 'recovers the Anthropic batch parser from the stored model path' do
      allow(connection).to receive(:get).and_return(
        instance_double(Faraday::Response, body: {
                          'name' => 'projects/test/locations/us-central1/batchPredictionJobs/123',
                          'state' => 'JOB_STATE_SUCCEEDED',
                          'model' => 'projects/test/locations/us-central1/publishers/anthropic/models/claude-haiku-4-5'
                        })
      )

      batch = provider.find_batch('123')

      expect(batch[:batch_protocol]).to be < RubyLLM::Providers::VertexAI::Anthropic
    end
  end

  describe '#list_models' do
    let(:location) { 'us-central1' }
    let(:connection) { instance_double(RubyLLM::Connection) }

    before do
      allow(RubyLLM::Connection).to receive(:new).and_return(connection)
      allow(connection).to receive(:get).and_return(catalog([]))
    end

    def catalog(models)
      instance_double(Faraday::Response, body: { 'publisherModels' => models })
    end

    def entry(publisher, name, actions: [], launch_stage: 'GA')
      {
        'name' => "publishers/#{publisher}/models/#{name}",
        'versionId' => '001',
        'launchStage' => launch_stage,
        'supportedActions' => actions.to_h { |action| [action, {}] }
      }
    end

    it 'lists directly served models by bare name and MaaS models by publisher-prefixed name' do
      allow(connection).to receive(:get).with('publishers/google/models').and_return(
        catalog([entry('google', 'gemini-3.5-flash'), entry('google', 'gemma-4-26b-a4b-it-maas'),
                 entry('google', 'text-embedding-005'), entry('google', 'veo-3.1-generate-001')])
      )
      allow(connection).to receive(:get).with('publishers/anthropic/models').and_return(
        catalog([entry('anthropic', 'claude-haiku-4-5')])
      )
      allow(connection).to receive(:get).with('publishers/mistralai/models').and_return(
        catalog([entry('mistralai', 'mistral-medium-3')])
      )
      allow(connection).to receive(:get).with('publishers/meta/models').and_return(
        catalog([entry('meta', 'llama-3.3-70b-instruct-maas')])
      )

      ids = provider.list_models.map(&:id)

      expect(ids).to include('gemini-3.5-flash', 'text-embedding-005', 'claude-haiku-4-5', 'mistral-medium-3',
                             'google/gemma-4-26b-a4b-it-maas', 'meta/llama-3.3-70b-instruct-maas')
      expect(ids).not_to include('veo-3.1-generate-001', 'llama-3.3-70b-instruct-maas')
    end

    it 'excludes deploy-it-yourself models, however they are named' do
      allow(connection).to receive(:get).with('publishers/google/models').and_return(
        catalog([entry('google', 'embeddinggemma', actions: %w[deploy multiDeployVertex])])
      )
      allow(connection).to receive(:get).with('publishers/mistralai/models').and_return(
        catalog([entry('mistralai', 'mistral-medium-3'),
                 entry('mistralai', 'mistral-large-3', actions: %w[deploy multiDeployVertex]),
                 entry('mistralai', 'codestral-2501-self-deploy', actions: %w[deploy multiDeployVertex])])
      )

      ids = provider.list_models.map(&:id)

      expect(ids).to include('mistral-medium-3')
      expect(ids).not_to include('embeddinggemma', 'mistral-large-3', 'codestral-2501-self-deploy')
    end

    it 'lists only the chat and embedding slice of Google’s mixed catalog' do
      allow(connection).to receive(:get).with('publishers/google/models').and_return(
        catalog([entry('google', 'gemini-3.5-flash'), entry('google', 'multimodalembedding'),
                 entry('google', 'imagen-4.0-generate-001'), entry('google', 'chirp-2'),
                 entry('google', 'face-detector'), entry('google', 'lyria-002')])
      )

      ids = provider.list_models.map(&:id)

      expect(ids).to include('gemini-3.5-flash', 'multimodalembedding')
      expect(ids).not_to include('imagen-4.0-generate-001', 'chirp-2', 'face-detector', 'lyria-002')
    end

    it 'gives publisher models a family and chat capabilities' do
      allow(connection).to receive(:get).with('publishers/anthropic/models').and_return(
        catalog([entry('anthropic', 'claude-haiku-4-5')])
      )
      allow(connection).to receive(:get).with('publishers/deepseek-ai/models').and_return(
        catalog([entry('deepseek-ai', 'deepseek-v3.2-maas'), entry('deepseek-ai', 'deepseek-ocr-maas')])
      )

      models = provider.list_models

      claude = models.find { |m| m.id == 'claude-haiku-4-5' }
      expect(claude.family).to eq('claude-haiku')
      expect(claude.capabilities).to include('function_calling')

      ocr = models.find { |m| m.id == 'deepseek-ai/deepseek-ocr-maas' }
      expect(ocr.family).to eq('deepseek')
      expect(ocr.capabilities).not_to include('function_calling')
    end

    it 'skips DEPRECATED models' do
      allow(connection).to receive(:get).with('publishers/anthropic/models').and_return(
        catalog([entry('anthropic', 'claude-3-opus', launch_stage: 'DEPRECATED')])
      )

      expect(provider.list_models.map(&:id)).not_to include('claude-3-opus')
    end

    it 'keeps the rest of the catalog when a publisher fails' do
      allow(connection).to receive(:get).with('publishers/google/models').and_raise(RubyLLM::Error.new)
      allow(connection).to receive(:get).with('publishers/anthropic/models').and_return(
        catalog([entry('anthropic', 'claude-sonnet-4-6')])
      )

      ids = provider.list_models.map(&:id)

      expect(ids).to include('claude-sonnet-4-6')
      expect(ids).to include('gemini-2.5-pro') # known models still fill the gap
    end
  end

  describe 'Anthropic protocol dialect' do
    let(:location) { 'us-east5' }
    let(:model) { instance_double(RubyLLM::Model::Info, id: 'claude-haiku-4-5', max_tokens: 4096) }
    let(:protocol) { RubyLLM::Providers::VertexAI::Anthropic.new(provider, model) }

    it 'speaks to rawPredict under the anthropic publisher' do
      expect(protocol.send(:completion_url)).to eq(
        'projects/test-project/locations/us-east5/publishers/anthropic/models/claude-haiku-4-5:rawPredict'
      )
      expect(protocol.send(:stream_url)).to eq(
        'projects/test-project/locations/us-east5/publishers/anthropic/models/claude-haiku-4-5:streamRawPredict'
      )
    end

    it 'swaps the model key for anthropic_version' do
      messages = [RubyLLM::Message.new(role: :user, content: 'hi')]

      payload = protocol.send(:render_payload, messages, tools: {}, temperature: nil, model:)

      expect(payload[:model]).to be_nil
      expect(payload[:anthropic_version]).to eq('vertex-2023-10-16')
      expect(payload.dig(:messages, 0, :role)).to eq('user')
    end
  end

  describe 'Mistral protocol dialect' do
    let(:location) { 'us-central1' }
    let(:model) { instance_double(RubyLLM::Model::Info, id: 'mistral-medium-3', max_tokens: 4096) }
    let(:protocol) { RubyLLM::Providers::VertexAI::Mistral.new(provider, model) }

    it 'reuses the Mistral dialect' do
      expect(described_class::Mistral.ancestors).to include(RubyLLM::Providers::Mistral::Chat)
    end

    it 'speaks to rawPredict under the mistralai publisher' do
      expect(protocol.send(:completion_url)).to eq(
        'projects/test-project/locations/us-central1/publishers/mistralai/models/mistral-medium-3:rawPredict'
      )
      expect(protocol.send(:stream_url)).to eq(
        'projects/test-project/locations/us-central1/publishers/mistralai/models/mistral-medium-3:streamRawPredict'
      )
    end

    it 'keeps the model key in the payload' do
      messages = [RubyLLM::Message.new(role: :user, content: 'hi')]

      payload = protocol.send(:render_payload, messages, tools: {}, temperature: nil, model:)

      expect(payload[:model]).to eq('mistral-medium-3')
      expect(payload.dig(:messages, 0, :role)).to eq('user')
    end
  end

  describe 'Chat Completions protocol dialect' do
    let(:location) { 'us-central1' }
    let(:model) { instance_double(RubyLLM::Model::Info, id: 'meta/llama-3.3-70b-instruct-maas', max_tokens: 4096) }
    let(:protocol) { RubyLLM::Providers::VertexAI::ChatCompletions.new(provider, model) }

    it 'speaks to the OpenAI-compatible endpoint' do
      expect(protocol.send(:completion_url)).to eq(
        'projects/test-project/locations/us-central1/endpoints/openapi/chat/completions'
      )
      expect(protocol.send(:stream_url)).to eq(protocol.send(:completion_url))
    end

    it 'keeps the publisher-prefixed model in the payload' do
      messages = [RubyLLM::Message.new(role: :user, content: 'hi')]

      payload = protocol.send(:render_payload, messages, tools: {}, temperature: nil, model:)

      expect(payload[:model]).to eq('meta/llama-3.3-70b-instruct-maas')
    end
  end
end

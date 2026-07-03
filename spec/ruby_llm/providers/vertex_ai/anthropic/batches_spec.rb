# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::VertexAI::Anthropic::Batches do
  let(:config) do
    instance_double(
      RubyLLM::Configuration,
      vertexai_batch_gcs_uri: 'gs://ruby-llm-batches/test',
      vertexai_location: 'us-central1',
      faraday_adapter: :net_http
    )
  end
  let(:provider) { instance_double(RubyLLM::Providers::VertexAI, slug: 'vertexai') }
  let(:connection) { instance_double(RubyLLM::Connection) }
  let(:protocol) do
    RubyLLM::Providers::VertexAI.batch_protocols.fetch(:anthropic).allocate.tap do |instance|
      instance.instance_variable_set(:@config, config)
      instance.instance_variable_set(:@provider, provider)
      instance.instance_variable_set(:@connection, connection)
    end
  end

  before do
    allow(provider).to receive_messages(
      location_path: 'projects/test/locations/us-central1',
      headers: { 'Authorization' => 'Bearer token' }
    )
    allow(provider).to receive(:model_path)
      .with('claude-haiku-4-5', publisher: 'anthropic')
      .and_return('projects/test/locations/us-central1/publishers/anthropic/models/claude-haiku-4-5')
  end

  describe '#vertex_batch_request' do
    it 'wraps Anthropic payloads in request rows' do
      request = {
        custom_id: '1',
        params: {
          messages: [{ role: 'user', content: 'Hi' }],
          anthropic_version: 'vertex-2023-10-16',
          stream: false
        }
      }

      expect(protocol.send(:vertex_batch_request, request)).to eq(
        custom_id: '1',
        request: {
          messages: [{ role: 'user', content: 'Hi' }],
          anthropic_version: 'vertex-2023-10-16'
        }
      )
    end
  end

  describe '#create_batch' do
    it 'uses the Anthropic publisher model path' do
      allow(provider).to receive(:upload_file)
      allow(connection).to receive(:post).and_return(
        instance_double(Faraday::Response, body: {
                          'name' => 'projects/test/locations/us-central1/batchPredictionJobs/123',
                          'state' => 'JOB_STATE_PENDING'
                        })
      )

      protocol.create_batch([
                              {
                                custom_id: '0',
                                model: 'claude-haiku-4-5',
                                params: { messages: [{ role: 'user', content: 'Hi' }] }
                              }
                            ])

      expect(connection).to have_received(:post).with(
        'projects/test/locations/us-central1/batchPredictionJobs',
        include(model: 'projects/test/locations/us-central1/publishers/anthropic/models/claude-haiku-4-5')
      )
    end

    it 'requires a regional endpoint' do
      allow(config).to receive(:vertexai_location).and_return('global')

      expect do
        protocol.create_batch([{ custom_id: '0', model: 'claude-haiku-4-5', params: { messages: [] } }])
      end.to raise_error(RubyLLM::ConfigurationError, /regional/)
    end
  end

  describe '#parse_vertex_batch_result' do
    it 'parses successful Anthropic responses by custom id' do
      line = {
        'custom_id' => '1',
        'response' => {
          'content' => [{ 'type' => 'text', 'text' => 'Hello' }],
          'usage' => { 'input_tokens' => 2, 'output_tokens' => 1 },
          'model' => 'claude-haiku-4-5'
        }
      }

      index, message = protocol.send(:parse_vertex_batch_result, line, 0)

      expect(index).to eq(1)
      expect(message.content).to eq('Hello')
      expect(message.model_id).to eq('claude-haiku-4-5')
    end
  end
end

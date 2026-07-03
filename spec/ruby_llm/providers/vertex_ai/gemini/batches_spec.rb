# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::VertexAI::Gemini::Batches do
  let(:config) do
    instance_double(
      RubyLLM::Configuration,
      vertexai_batch_gcs_uri: 'gs://ruby-llm-batches/test',
      faraday_adapter: :net_http
    )
  end
  let(:provider) { instance_double(RubyLLM::Providers::VertexAI, slug: 'vertexai') }
  let(:connection) { instance_double(RubyLLM::Connection) }
  let(:protocol) do
    RubyLLM::Providers::VertexAI.batch_protocols.fetch(:gemini).allocate.tap do |instance|
      instance.instance_variable_set(:@config, config)
      instance.instance_variable_set(:@provider, provider)
      instance.instance_variable_set(:@connection, connection)
    end
  end

  before do
    model_path = 'projects/test/locations/us-central1/publishers/google/models/gemini-2.5-flash'

    allow(provider).to receive_messages(
      location_path: 'projects/test/locations/us-central1',
      headers: { 'Authorization' => 'Bearer token' }
    )
    allow(provider).to receive(:model_path).with('gemini-2.5-flash').and_return(model_path)
  end

  describe '#vertex_batch_request' do
    it 'adds the submission index as a request label' do
      request = {
        custom_id: '2',
        params: {
          contents: [{ role: 'user', parts: [{ text: 'Hi' }] }],
          labels: { existing: 'label' }
        }
      }

      expect(protocol.send(:vertex_batch_request, request)).to eq(
        request: {
          'contents' => [{ 'role' => 'user', 'parts' => [{ 'text' => 'Hi' }] }],
          'labels' => { 'existing' => 'label', 'ruby_llm_batch_id' => '2' }
        }
      )
    end
  end

  describe '#create_batch' do
    it 'rejects mixed-model jobs' do
      requests = [
        { custom_id: '0', model: 'gemini-2.5-flash', params: {} },
        { custom_id: '1', model: 'gemini-3-flash-preview', params: {} }
      ]

      expect { protocol.create_batch(requests) }.to raise_error(RubyLLM::Error, /one model/)
    end

    it 'requires a GCS bucket prefix' do
      allow(config).to receive(:vertexai_batch_gcs_uri).and_return(nil)

      expect do
        protocol.create_batch([{ custom_id: '0', model: 'gemini-2.5-flash', params: {} }])
      end.to raise_error(RubyLLM::ConfigurationError, /vertexai_batch_gcs_uri/)
    end

    it 'uploads JSONL to GCS and creates a Vertex batch prediction job' do
      uploaded_body = nil
      allow(provider).to receive(:upload_file) do |io, **|
        uploaded_body = io.string
      end
      allow(connection).to receive(:post).and_return(
        instance_double(Faraday::Response, body: {
                          'name' => 'projects/test/locations/us-central1/batchPredictionJobs/123',
                          'state' => 'JOB_STATE_PENDING'
                        })
      )

      protocol.create_batch([
                              {
                                custom_id: '0',
                                model: 'gemini-2.5-flash',
                                params: { contents: [{ role: 'user', parts: [{ text: 'Hi' }] }] }
                              }
                            ])

      expect(uploaded_body).to include('ruby_llm_batch_id')
      expect(provider).to have_received(:upload_file).with(
        kind_of(StringIO),
        uri: match(%r{\Ags://ruby-llm-batches/test/ruby_llm_batches/.+/input\.jsonl\z}),
        filename: 'input.jsonl',
        content_type: 'application/jsonl'
      )
      expect(connection).to have_received(:post).with(
        'projects/test/locations/us-central1/batchPredictionJobs',
        include(
          model: 'projects/test/locations/us-central1/publishers/google/models/gemini-2.5-flash',
          inputConfig: include(
            instancesFormat: 'jsonl',
            gcsSource: include(
              uris: [
                match(%r{\Ags://ruby-llm-batches/test/ruby_llm_batches/.+/input\.jsonl\z})
              ]
            )
          ),
          outputConfig: include(predictionsFormat: 'jsonl')
        )
      )
    end
  end

  describe '#batch_results' do
    it 'raises when the job has no GCS output URI yet' do
      allow(connection).to receive(:get).and_return(
        instance_double(Faraday::Response, body: { 'state' => 'JOB_STATE_RUNNING' })
      )

      expect { protocol.batch_results('123') }.to raise_error(RubyLLM::Error, /no GCS output URI/)
    end
  end

  describe '#parse_vertex_batch_result' do
    it 'parses successful rows by label' do
      line = {
        'request' => { 'labels' => { 'ruby_llm_batch_id' => '1' } },
        'response' => {
          'candidates' => [{ 'content' => { 'parts' => [{ 'text' => 'Jupiter' }] } }],
          'modelVersion' => 'gemini-2.5-flash',
          'usageMetadata' => { 'promptTokenCount' => 5, 'candidatesTokenCount' => 3 }
        }
      }

      index, message = protocol.send(:parse_vertex_batch_result, line, 0)

      expect(index).to eq(1)
      expect(message.content).to eq('Jupiter')
    end
  end
end

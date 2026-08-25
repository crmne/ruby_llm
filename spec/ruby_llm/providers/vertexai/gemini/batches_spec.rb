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
        payload: {
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
        { custom_id: '0', model: 'gemini-2.5-flash', payload: {} },
        { custom_id: '1', model: 'gemini-3-flash-preview', payload: {} }
      ]

      expect { protocol.create_batch(requests) }.to raise_error(RubyLLM::Error, /one model/)
    end

    it 'requires a GCS bucket prefix' do
      allow(config).to receive(:vertexai_batch_gcs_uri).and_return(nil)

      expect do
        protocol.create_batch([{ custom_id: '0', model: 'gemini-2.5-flash', payload: {} }])
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
                                payload: { contents: [{ role: 'user', parts: [{ text: 'Hi' }] }] }
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
        ),
        idempotent: false
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

    it 'reports a failed row whose status is a plain string' do
      line = { 'request' => { 'labels' => { 'ruby_llm_batch_id' => '1' } }, 'status' => 'Internal error occurred' }

      expect(protocol.send(:parse_vertex_batch_result, line, 0)).to eq([1, nil])
    end
  end

  describe '#find_batch and #cancel_batch' do
    let(:job) do
      {
        'name' => 'projects/test/locations/us-central1/batchPredictionJobs/1',
        'state' => 'JOB_STATE_SUCCEEDED',
        'completionStats' => { 'successfulCount' => 2 },
        'model' => 'projects/test/locations/us-central1/publishers/google/models/gemini-2.5-flash'
      }
    end

    it 'reads a job by bare id' do
      allow(connection).to receive(:get)
        .with('projects/test/locations/us-central1/batchPredictionJobs/1')
        .and_return(Struct.new(:body).new(job))

      expect(protocol.find_batch('1')).to include(
        id: job['name'], status: 'JOB_STATE_SUCCEEDED', completed: true,
        request_counts: { 'successfulCount' => 2 }, model: job['model']
      )
    end

    it 'reads a job by full resource name' do
      allow(connection).to receive(:get).with(job['name']).and_return(Struct.new(:body).new(job))

      expect(protocol.find_batch(job['name'])[:id]).to eq(job['name'])
    end

    it 'reports a running job as incomplete' do
      allow(connection).to receive(:get).and_return(
        Struct.new(:body).new(job.merge('state' => 'JOB_STATE_RUNNING'))
      )

      expect(protocol.find_batch('1')[:completed]).to be(false)
    end

    it 'cancels a job and reads it back' do
      allow(connection).to receive(:post)
        .with('projects/test/locations/us-central1/batchPredictionJobs/1:cancel', {})
      allow(connection).to receive(:get).and_return(Struct.new(:body).new(job))

      expect(protocol.cancel_batch('1')[:id]).to eq(job['name'])
      expect(connection).to have_received(:post)
    end
  end

  describe '#batch_results over the output shards' do
    it 'reads every JSONL shard the job wrote' do
      job = {
        'outputInfo' => { 'gcsOutputDirectory' => 'gs://ruby-llm-batches/test/output' },
        'state' => 'JOB_STATE_SUCCEEDED'
      }
      allow(connection).to receive(:get).and_return(Struct.new(:body).new(job))
      allow(provider).to receive(:list_file_uris).with('gs://ruby-llm-batches/test/output').and_return(
        ['gs://ruby-llm-batches/test/output/predictions.jsonl', 'gs://ruby-llm-batches/test/output/manifest.txt']
      )
      row = {
        'response' => {
          'candidates' => [{ 'content' => { 'parts' => [{ 'text' => 'Hello' }] } }],
          'modelVersion' => 'gemini-2.5-flash'
        }
      }
      allow(provider).to receive(:download_file).and_return("\n#{row.to_json}\n")

      results = protocol.batch_results('1')

      expect(results.length).to eq(1)
      expect(results.first.last.content).to eq('Hello')
    end
  end
end

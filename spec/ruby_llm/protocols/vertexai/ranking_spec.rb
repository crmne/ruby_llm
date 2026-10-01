# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Protocols::VertexAI::Ranking do
  let(:model) { model_for(:vertexai, :vertexai_rerank) }
  let(:context) do
    RubyLLM.context do |config|
      config.vertexai_project_id = 'ranking-project'
      config.vertexai_location = 'us-central1'
    end
  end
  let(:provider) { RubyLLM::Providers::VertexAI.new(context.config) }
  let(:protocol) { described_class.new(provider, RubyLLM::Model.default(model, :vertexai)) }
  let(:endpoint) do
    'https://discoveryengine.googleapis.com/v1/projects/ranking-project/' \
      'locations/global/rankingConfigs/default_ranking_config:rank'
  end

  before do |example|
    next if example.metadata[:live]

    allow(provider).to receive(:headers).and_return('Authorization' => 'Bearer ranking-test')
    allow(RubyLLM::Providers::VertexAI).to receive(:new).with(context.config).and_return(provider)
  end

  it 'ranks real documents through the configured Discovery Engine service', :live do
    unless VCR.current_cassette.recording? || VCR.current_cassette.http_interactions.interactions.any?
      skip 'No recorded Vertex ranking response; recording requires a project with Discovery Engine enabled'
    end

    result = RubyLLM.rerank('Ruby language', documents, model:, provider: :vertexai,
                                                        assume_model_exists: true, top_n: 1)
    expect(result.results.first).to have_attributes(index: 1, document: documents.last, score: be_between(0, 1))
    expect(result.tokens.input).to be_nil
    expect(result.cost.total).to be_nil
  rescue RubyLLM::ForbiddenError => e
    raise unless e.message.include?('Discovery Engine API') && e.message.include?('disabled')

    VCR.current_cassette.new_recorded_interactions.clear
    skip 'Discovery Engine API is disabled in the configured Google Cloud project'
  end

  def documents
    ['Bananas are fruit.', 'Ruby is a programming language.']
  end

  it 'uses Discovery Engine with existing credentials and correlates records that omit their original text' do
    request = stub_request(:post, endpoint).with do |req|
      expect(req.headers).to include('Authorization' => 'Bearer ranking-test',
                                     'X-Goog-User-Project' => 'ranking-project')
      expect(JSON.parse(req.body)).to eq(
        'model' => model, 'query' => 'Ruby language', 'topN' => 1, 'ignoreRecordDetailsInResponse' => true,
        'records' => [{ 'id' => '0', 'content' => documents.first }, { 'id' => '1', 'content' => documents.last }]
      )
    end.to_return_json(body: { records: [{ id: '1', score: 0.9876 }] })

    result = context.rerank('Ruby language', documents, model:, provider: :vertexai, assume_model_exists: true,
                                                        top_n: 1,
                                                        provider_options: { ignoreRecordDetailsInResponse: true })

    expect(result.results.first).to have_attributes(index: 1, document: documents.last, score: 0.9876)
    expect(result.raw).to eq('records' => [{ 'id' => '1', 'score' => 0.9876 }])
    expect(result.model).to eq(model)
    expect(result.tokens.to_h).to eq({})
    expect(result.cost.total).to be_nil
    expect(result.ruby_llm_usage_entries.map(&:status)).to eq([:succeeded])
    expect(request).to have_been_requested.once
  end

  it 'honors a separate endpoint and ranking resource while retaining provider result order' do
    context.config.vertexai_ranking_api_base = 'https://ranking.test/proxy/v1'
    context.config.vertexai_ranking_config = 'projects/ranking-project/locations/eu/rankingConfigs/custom'
    request = stub_request(:post, 'https://ranking.test/proxy/v1/projects/ranking-project/' \
                                  'locations/eu/rankingConfigs/custom:rank')
              .to_return_json(body: { records: [{ id: '1', score: 0.9 }, { id: '0', score: 0.0 }] })

    result = protocol.rerank('Ruby', documents, model:)

    expect(result.results.map(&:index)).to eq([1, 0])
    expect(result.results.map(&:document)).to eq(documents.reverse)
    expect(result.results.last.score).to eq(0.0)
    expect(provider.api_base).to eq('https://us-central1-aiplatform.googleapis.com/v1beta1')
    expect(request).to have_been_requested.once
  end

  it 'preserves service-disabled errors instead of returning empty results or fabricated usage' do
    stub_request(:post, endpoint).to_return_json(status: 403, body: {
                                                   error: { code: 403, message: 'Discovery Engine API is disabled',
                                                            status: 'PERMISSION_DENIED' }
                                                 })

    expect { protocol.rerank('Ruby', documents, model:) }
      .to raise_error(RubyLLM::ForbiddenError, /Discovery Engine API is disabled/)
  end

  it 'rejects documents its records cannot carry before HTTP' do
    expect { protocol.rerank('Ruby', [1], model:) }.to raise_error(ArgumentError, /documents must be text/)
    expect(a_request(:post, endpoint)).not_to have_been_made
  end

  it 'leaves document counts, empty text, and top_n to Vertex AI Search' do
    stub_request(:post, endpoint).to_return_json(body: { records: [] })

    protocol.rerank('', Array.new(1001, ''), model:, top_n: 0)

    expect(a_request(:post, endpoint).with { |request| JSON.parse(request.body)['topN'].zero? }).to have_been_made
  end

  it 'rejects document ids that do not map back onto the documents' do
    ['2', '-1', '01', 1].each do |id|
      stub_request(:post, endpoint).to_return_json(body: { records: [{ id:, score: 0.8 }] })
      expect { protocol.rerank('Ruby', documents, model:) }.to raise_error(RubyLLM::Error, /invalid document id/)
    end
  end

  it 'rejects a document id returned twice' do
    stub_request(:post, endpoint).to_return_json(body: { records: [{ id: '0', score: 0.9 }, { id: '0', score: 0.8 }] })

    expect { protocol.rerank('Ruby', documents, model:) }.to raise_error(RubyLLM::Error, /duplicate document id/)
  end
end

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

  it 'rejects invalid input before HTTP' do
    [[], Array.new(1001, 'text'), [1], ['']].each do |input|
      expect { protocol.rerank('Ruby', input, model:) }.to raise_error(ArgumentError, /documents/)
    end
    expect { protocol.rerank('', documents, model:) }.to raise_error(ArgumentError, /query/)
    expect { protocol.rerank('Ruby', documents, model:, top_n: 0) }.to raise_error(ArgumentError, /top_n/)
    expect(a_request(:post, endpoint)).not_to have_been_made
  end

  it 'rejects malformed or duplicate document identities and absent scores' do
    invalid = [{ id: '2', score: 0.8 }, { id: '-1', score: 0.8 }, { id: '01', score: 0.8 },
               { id: 1, score: 0.8 }, { id: '1' }, { id: '1', score: '0.8' }, nil]
    invalid.each do |record|
      stub_request(:post, endpoint).to_return_json(body: { records: [record] })
      expect do
        protocol.rerank('Ruby', documents, model:)
      end.to raise_error(RubyLLM::Error, /invalid document id or score/)
    end
    stub_request(:post, endpoint).to_return_json(body: { records: [{ id: '1', score: 0.9 }, { id: '1', score: 0.8 }] })
    expect { protocol.rerank('Ruby', documents, model:) }.to raise_error(RubyLLM::Error, /duplicate document id/)
    stub_request(:post, endpoint).to_return_json(body: {})
    expect { protocol.rerank('Ruby', documents, model:) }.to raise_error(RubyLLM::Error, /no ranking records/)
  end
end

# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::Azure::Cohere do
  include_context 'with configured RubyLLM'

  let(:model) { model_for(:azure, :azure_cohere_embedding) }
  let(:v3_model) { model_for(:azure, :embedding) }
  let(:rerank_model) { model_for(:azure, :azure_cohere_rerank) }
  let(:base) { 'https://azure.example.test/providers/cohere/v2' }
  let(:image_path) { File.expand_path('../../../fixtures/ruby.png', __dir__) }

  before do |example|
    RubyLLM.config.azure_api_base = 'https://azure.example.test' unless example.metadata[:live]
  end

  def embedding_body(vectors = [[0.1, 0.2]])
    { embeddings: { float: vectors }, meta: { billed_units: { input_tokens: 12 } } }
  end

  it 'rejects chat and batches on the embedding and reranking adapter before HTTP' do
    context = RubyLLM.context { |config| config.azure_protocol = :cohere }
    chat = context.chat(model: model_for(:azure), provider: :azure)
    expect { chat.ask('Hello') }.to raise_error(RubyLLM::Error, /doesn't support chat/)
    expect { chat.provider.batch_results('batch_test', batch_protocol: described_class) }
      .to raise_error(RubyLLM::Error, /doesn't support batch requests/)
    expect(a_request(:any, /azure\.example\.test/)).not_to have_been_made
  end

  it 'does not expose native Cohere catalog, OCR, transcription, or tokenization endpoints' do
    provider = RubyLLM::Providers::Azure.new(RubyLLM.config)
    protocol = described_class.new(provider)
    %i[models_url ocr_url transcription_url tokenization_url].each do |method|
      expect { protocol.send(method) }.to raise_error(NotImplementedError)
    end
    expect(a_request(:any, /azure\.example\.test/)).not_to have_been_made
  end

  it 'selects the Cohere operation for known deployments while preserving OpenAI embeddings' do
    request = stub_request(:post, "#{base}/embed").with do |req|
      JSON.parse(req.body) == { 'model' => model, 'texts' => ['Ruby'], 'input_type' => 'search_query',
                                'output_dimension' => 2, 'embedding_types' => ['float'], 'truncate' => 'NONE' }
    end.to_return_json(body: embedding_body)

    result = RubyLLM.embed('Ruby', model:, provider: :azure, dimensions: 2, task_type: 'search_query',
                                   provider_options: { truncate: 'NONE' })

    expect(result.vectors).to eq([0.1, 0.2])
    expect(result.tokens.input).to eq(12)
    expect(request).to have_been_requested.once
    provider = RubyLLM::Providers::Azure.new(RubyLLM.config)
    openai_model = RubyLLM.models.find('text-embedding-3-small', provider: :azure)
    expect(provider.protocol_for(openai_model, operation: :embed).ancestors)
      .to include(RubyLLM::Providers::Azure::ChatCompletions)
  end

  it 'keeps scalar and array embeddings distinct and preserves v4 mixed content order' do
    stub_request(:post, "#{base}/embed").to_return_json(body: embedding_body)
    result = RubyLLM.embed(['Ruby'], model:, provider: :azure)
    expect(result.vectors).to eq([[0.1, 0.2]])

    request = stub_request(:post, "#{base}/embed").with do |req|
      payload = JSON.parse(req.body)
      next false unless payload['inputs']

      parts = payload.fetch('inputs').first.fetch('content')
      parts.first == { 'type' => 'text', 'text' => 'A ruby' } &&
        parts.last.dig('image_url', 'url').start_with?('data:image/png;base64,') && !payload.key?('texts')
    end.to_return_json(body: embedding_body)

    expect(RubyLLM.embed('A ruby', model:, provider: :azure, with: image_path).vectors).to eq([0.1, 0.2])
    expect(request).to have_been_requested.once
  end

  it 'maps v3 image-only embeddings to the supported Cohere image representation' do
    request = stub_request(:post, "#{base}/embed").with do |req|
      payload = JSON.parse(req.body)
      payload['input_type'] == 'image' && payload.fetch('images').one? &&
        payload['images'].first.start_with?('data:image/png;base64,') &&
        !payload.key?('texts') && !payload.key?('inputs')
    end.to_return_json(body: embedding_body)

    result = RubyLLM.embed(nil, model: v3_model, provider: :azure, with: image_path)
    expect(result.vectors).to eq([0.1, 0.2])
    expect(result.tokens.input).to eq(12)
    expect(request).to have_been_requested.once
  end

  it 'rejects unsupported v3 mixed media before any request' do
    expect { RubyLLM.embed('A ruby', model: v3_model, provider: :azure, with: image_path) }
      .to raise_error(ArgumentError, /not both/)
    expect { RubyLLM.embed(nil, model: v3_model, provider: :azure, with: [image_path, image_path]) }
      .to raise_error(ArgumentError, /one image/)
    expect do
      RubyLLM.embed(nil, model: v3_model, provider: :azure,
                         with: RubyLLM::Attachment.new(StringIO.new('audio'), filename: 'voice.wav'))
    end.to raise_error(RubyLLM::UnsupportedAttachmentError)
    expect(a_request(:post, "#{base}/embed")).not_to have_been_made
  end

  it 'routes reranking to Cohere and retains original documents and reported usage only' do
    documents = ['Bananas are fruit.', { title: 'Ruby', body: 'A programming language.' }]
    request = stub_request(:post, "#{base}/rerank").with do |req|
      JSON.parse(req.body) == { 'model' => rerank_model, 'query' => 'Ruby language',
                                'documents' => JSON.parse(JSON.generate(documents)),
                                'top_n' => 1, 'max_tokens_per_doc' => 128 }
    end.to_return_json(body: { results: [{ index: 1, relevance_score: 0.9 }],
                               meta: { billed_units: { search_units: 1 } } })
    result = RubyLLM.rerank('Ruby language', documents, model: rerank_model, provider: :azure,
                                                        top_n: 1, provider_options: { max_tokens_per_doc: 128 })
    expect(result.results.first).to have_attributes(index: 1, document: documents.last, score: 0.9)
    expect(result.tokens.input).to be_nil
    expect(result.cost.total).to be_nil
    expect(result.raw.dig('meta', 'billed_units', 'search_units')).to eq(1)
    expect(request).to have_been_requested.once
  end

  it 'handles resource and Cohere endpoint bases without duplicate paths or credential forwarding' do
    ['https://res.services.ai.azure.com', 'https://res.services.ai.azure.com/openai/v1',
     'https://res.services.ai.azure.com/providers/cohere',
     'https://res.services.ai.azure.com/providers/cohere/v2/embed'].each do |api_base|
      context = RubyLLM.context do |config|
        config.azure_api_base = api_base
        config.azure_api_key = 'resource-key'
        config.cohere_api_key = 'unrelated-key'
      end
      request = stub_request(:post, 'https://res.services.ai.azure.com/providers/cohere/v2/embed')
                .with(headers: { 'Api-Key' => 'resource-key' }).to_return_json(body: embedding_body)
      expect(context.embed('Ruby', model:, provider: :azure).vectors).to eq([0.1, 0.2])
      expect(request).to have_been_requested.at_least_once
    end
  end

  it 'uses the configured serverless endpoint and its own bearer key for named custom deployments' do
    context = RubyLLM.context do |config|
      config.azure_api_base = 'https://rerank.eastus.models.ai.azure.com/v2/rerank'
      config.azure_api_key = 'deployment-key'
      config.azure_protocol = :cohere
    end
    request = stub_request(:post, 'https://rerank.eastus.models.ai.azure.com/v2/rerank')
              .with { |req| req.headers['Authorization'] == 'Bearer deployment-key' && !req.headers.key?('Api-Key') }
              .to_return_json(body: { results: [{ index: 0, relevance_score: 0.8 }] })

    result = context.rerank('Ruby', ['Ruby language'], model: 'my-rerank-deployment', provider: :azure)
    expect(result.results.first.score).to eq(0.8)
    expect(request).to have_been_requested.once
  end

  it 'preserves Azure deployment errors without falling back to another host' do
    stub_request(:post, "#{base}/rerank")
      .to_return_json(status: 404, body: { error: { code: 'DeploymentNotFound', message: 'Deployment not found' } })
    expect { RubyLLM.rerank('Ruby', ['Ruby language'], model: rerank_model, provider: :azure) }
      .to raise_error(RubyLLM::Error, /Deployment not found/)
  end

  it 'embeds an image through the active Azure Cohere endpoint with billed usage', :live do
    result = RubyLLM.embed(nil, model: v3_model, provider: :azure, with: image_path)

    expect(result.vectors.size).to eq(1024)
    expect(result.vectors).to all(be_a(Float))
    expect(result.tokens.input).to be_positive
    expect(result.ruby_llm_usage_entries.map(&:status)).to eq([:succeeded])
  end

  it 'reranks documents through the configured Azure Cohere deployment', :live do
    skip_without_cassette_or_key('AZURE_API_KEY')
    documents = ['Bananas are fruit.', 'Ruby is a programming language.']
    result = RubyLLM.rerank('Ruby programming', documents, model: rerank_model, provider: :azure, top_n: 1)

    expect(result.results.first).to have_attributes(index: 1, document: documents.last)
    expect(result.results.first.score).to be_a(Numeric)
    expect(result.ruby_llm_usage_entries.map(&:status)).to eq([:succeeded])
  rescue RubyLLM::Error => e
    raise unless e.response&.status == 404

    body = e.response.body
    body = JSON.parse(body) if body.is_a?(String)
    raise unless body.dig('error', 'code') == 'DeploymentNotFound'

    skip 'The configured Azure resource has no deployment for the selected Cohere rerank model'
  end
end

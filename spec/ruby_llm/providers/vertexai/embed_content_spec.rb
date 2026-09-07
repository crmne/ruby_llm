# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::VertexAI::EmbedContent do
  let(:provider) do
    config = RubyLLM::Configuration.new
    config.vertexai_project_id = 'test-project'
    config.vertexai_location = 'global'
    RubyLLM::Providers::VertexAI.new(config)
  end
  let(:model) { RubyLLM.models.find(model_for(:vertexai, :multimodal_embedding), provider: :vertexai) }
  let(:protocol) { described_class.new(provider, model) }

  it 'routes Gemini Embedding 2 to embedContent and keeps text embeddings on predict' do
    expect(provider.protocol_for(model, operation: :embed)).to eq(described_class)
    expect(protocol.embedding_url(model: model.id)).to eq(
      "projects/test-project/locations/global/publishers/google/models/#{model.id}:embedContent"
    )

    legacy = RubyLLM.models.find(model_for(:vertexai, :embedding), provider: :vertexai)
    legacy_protocol = provider.protocol_for(legacy, operation: :embed).new(provider, legacy)
    expect(legacy_protocol.send(:embedding_url, model: legacy.id)).to end_with("/#{legacy.id}:predict")
    expect(legacy_protocol.send(:supports_embedding_media?)).to be(false)
    expect(provider.render_embedding('Ruby', model: legacy)).to eq(instances: [{ content: 'Ruby' }])
    expect(provider.render_embedding('Ruby', model:)).to eq(content: { parts: [{ text: 'Ruby' }] })
  end

  it 'combines text and media into one content with output dimensions' do
    file = RubyLLM::UploadedFile.new(id: 'gs://images/logo.png', uri: 'gs://images/logo.png', mime_type: 'image/png')
    payload = protocol.render_embedding_payload(
      'The Ruby logo', model: model.id, dimensions: 128, with: RubyLLM::Attachment.wrap(file)
    )

    expect(payload).to eq(
      content: { parts: [{ text: 'The Ruby logo' },
                         { file_data: { mime_type: 'image/png', file_uri: 'gs://images/logo.png' } }] },
      outputDimensionality: 128
    )
  end

  it 'keeps inline media when there is no text prompt' do
    path = File.expand_path('../../../fixtures/ruby.png', __dir__)
    payload = protocol.render_embedding_payload(nil, model: model.id, dimensions: nil,
                                                     with: RubyLLM::Attachment.wrap(path))

    expect(payload[:content][:parts]).to contain_exactly(
      inline_data: { mime_type: 'image/png', data: Base64.strict_encode64(File.binread(path)) }
    )
  end

  it 'rejects several texts instead of aggregating them into one embedding' do
    expect do
      protocol.render_embedding_payload(%w[Ruby Rails], model: model.id, dimensions: nil)
    end.to raise_error(ArgumentError, /one text at a time/)
  end

  it 'rejects unsupported task fields instead of silently dropping them' do
    expect do
      protocol.render_embedding_payload('Ruby', model: model.id, dimensions: nil, task_type: 'RETRIEVAL_QUERY')
    end.to raise_error(ArgumentError, /task instructions and titles in the text/)
  end

  it 'reads the single vector and reported input tokens' do
    response = instance_double(Faraday::Response, body: {
                                 'embedding' => { 'values' => [0.1, 0.2] },
                                 'usageMetadata' => { 'promptTokenCount' => 258 }
                               })
    result = protocol.parse_embedding_response(response, model: model.id, text: 'Ruby')

    expect(result.vectors).to eq([0.1, 0.2])
    expect(result.tokens.input).to eq(258)
    expect(protocol.parse_embedding_response(response, model: model.id, text: ['Ruby']).vectors).to eq([[0.1, 0.2]])
  end

  it 'raises when the endpoint returns no vector' do
    response = instance_double(Faraday::Response, body: { 'embedding' => { 'values' => [] } })

    expect { protocol.parse_embedding_response(response, model: model.id, text: 'Ruby') }
      .to raise_error(RubyLLM::Error, 'Vertex AI returned no embedding')
  end

  it 'embeds text and an image through Vertex Gemini Embedding 2', :live do
    result = RubyLLM.embed(
      'The Ruby logo', model: model_for(:vertexai, :multimodal_embedding), provider: :vertexai,
                       with: File.expand_path('../../../fixtures/ruby.png', __dir__), dimensions: 128
    )

    expect(result.vectors.size).to eq(128)
    expect(result.vectors).to all(be_a(Float))
    expect(result.tokens.input).to be_positive
  end
end

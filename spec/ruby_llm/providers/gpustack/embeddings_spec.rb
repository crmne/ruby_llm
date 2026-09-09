# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::GPUStack::Embeddings do
  let(:protocol) { RubyLLM::Providers::GPUStack::ChatCompletions.allocate }
  let(:model) { model_for(:gpustack) }
  let(:image) { RubyLLM::Attachment.new(StringIO.new('png bytes'), filename: 'logo.png') }
  let(:image_part) do
    { type: 'image_url', image_url: { url: 'data:image/png;base64,cG5nIGJ5dGVz', detail: 'auto' } }
  end

  def render(text, **options)
    protocol.send(:render_embedding_payload, text, model:, dimensions: 256, **options)
  end

  it 'embeds text and an image through the messages request format' do
    expect(render('The Ruby logo', with: [image])).to eq(
      model: model,
      dimensions: 256,
      messages: [{ role: 'user', content: [{ type: 'text', text: 'The Ruby logo' }, image_part] }]
    )
  end

  it 'embeds an image without text' do
    expect(render(nil, with: [image])).to eq(
      model: model, dimensions: 256, messages: [{ role: 'user', content: [image_part] }]
    )
  end

  it 'preserves text batches and provider options' do
    expect(render(%w[Ruby Rails], provider_options: { dimensions: 128, encoding_format: 'float' })).to eq(
      model: model, input: %w[Ruby Rails], dimensions: 128, encoding_format: 'float'
    )
  end

  it 'rejects ambiguous attachment and multiple-text combinations' do
    expect { render(%w[Ruby Rails], with: [image]) }.to raise_error(ArgumentError, /one text at a time/)
  end

  it 'rejects attachments the backend cannot render' do
    document = RubyLLM::Attachment.new(StringIO.new('docx bytes'), filename: 'report.docx')

    expect { render('The report', with: [document]) }.to raise_error(RubyLLM::UnsupportedAttachmentError)
  end

  it 'accepts image attachments through the public API and returns one vector' do
    request = stub_request(:post, 'http://localhost:11444/v1/embeddings')
              .with(body: { model: model, messages: [{ role: 'user', content: [image_part] }] })
              .to_return_json(body: { data: [{ embedding: [0.1, 0.2] }], usage: { prompt_tokens: 12 } })

    context = RubyLLM.context { |config| config.gpustack_api_base = 'http://localhost:11444/v1' }
    result = context.embed(nil, model:, provider: :gpustack, with: image)

    expect(request).to have_been_requested.once
    expect(result.vectors).to eq([0.1, 0.2])
    expect(result.tokens.input).to eq(12)
  end
end

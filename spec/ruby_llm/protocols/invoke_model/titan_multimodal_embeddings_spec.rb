# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Protocols::InvokeModel::TitanMultimodalEmbeddings do
  include_context 'with configured RubyLLM'

  let(:provider) { RubyLLM::Providers::Bedrock.new(RubyLLM.config) }
  let(:protocol) { described_class.new(provider) }
  let(:model) { 'amazon.titan-embed-image-v1' }
  let(:image) { RubyLLM::Attachment.new(File.expand_path('../../../fixtures/ruby.png', __dir__)) }
  let(:audio) { File.expand_path('../../../fixtures/ruby.wav', __dir__) }

  it 'sends the image beside the text' do
    payload = protocol.send(:render_embedding_payload, 'Hello', dimensions: 256, image:, provider_options: {})

    expect(payload).to eq(
      inputText: 'Hello', inputImage: image.encoded, embeddingConfig: { outputEmbeddingLength: 256 }
    )
  end

  it 'sends an image without text' do
    payload = protocol.send(:render_embedding_payload, nil, dimensions: nil, image:, provider_options: {})

    expect(payload).to eq(inputImage: image.encoded)
  end

  it 'rejects anything but one image for one text' do
    expect { protocol.embed('Hi', model:, dimensions: nil, with: audio) }
      .to raise_error(RubyLLM::UnsupportedAttachmentError)
    expect { protocol.embed('Hi', model:, dimensions: nil, with: [image, image]) }
      .to raise_error(ArgumentError, /one attachment at a time/)
    expect { protocol.embed(%w[a b], model:, dimensions: nil, with: image) }
      .to raise_error(ArgumentError, /one text at a time/)
  end
end

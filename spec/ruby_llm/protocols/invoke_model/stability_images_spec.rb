# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Protocols::InvokeModel::StabilityImages do
  let(:provider) do
    config = RubyLLM::Configuration.new
    config.bedrock_region = 'us-west-2'
    config.bedrock_api_key = 'test'
    config.bedrock_secret_key = 'test'
    RubyLLM::Providers::Bedrock.new(config)
  end
  let(:model) { RubyLLM.models.find(model_for(:bedrock, :bedrock_image), provider: :bedrock) }
  let(:edit_model) { model_for(:bedrock, :bedrock_image_edit) }
  let(:protocol) { described_class.new(provider, model) }
  let(:image) { RubyLLM::Attachment.new(image_path) }

  def image_path
    File.expand_path('../../../fixtures/ruby.png', __dir__)
  end

  def render(prompt = 'A blue teapot', **options)
    protocol.render_image_payload(prompt, model: model.id, size: nil, **options)
  end

  it 'selects the image protocol without changing chat or embedding routing' do
    expect(provider.protocol_for(model, operation: :paint)).to eq(described_class)
    expect(provider.protocol_for(RubyLLM.models.find(edit_model, provider: :bedrock), operation: :paint))
      .to eq(described_class)
    expect(provider.protocol_for(RubyLLM.models.find(model_for(:bedrock), provider: :bedrock)))
      .to eq(provider.protocols.fetch(:converse))
    expect(provider.protocol_for(RubyLLM.models.find(model_for(:bedrock, :embedding), provider: :bedrock),
                                 operation: :embed)).to eq(provider.protocols.fetch(:titan_text_embeddings))
  end

  it 'rejects image generation on unsupported models before invoking them' do
    chat_model = RubyLLM.models.find(model_for(:bedrock), provider: :bedrock)

    expect { provider.protocol_for(chat_model, operation: :paint) }.to raise_error(RubyLLM::Error, /not supported/)
  end

  it 'renders prompt, aspect ratio, and provider generation options' do
    expect(render(size: '1536x1024', provider_options: { seed: 42, output_format: 'jpeg' }))
      .to eq(prompt: 'A blue teapot', aspect_ratio: '3:2', seed: 42, output_format: 'jpeg')
    expect(render(size: '16:9')).to include(aspect_ratio: '16:9')
    expect(render(size: '21:9')).to include(aspect_ratio: '21:9')
    expect(render(size: '900x2100')).to include(aspect_ratio: '9:21')
    expect(render).to eq(prompt: 'A blue teapot')
  end

  it 'rejects invalid and unsupported aspect ratios' do
    %w[large 0x1024 100x300].each do |size|
      expect { render(size:) }.to raise_error(ArgumentError)
    end
  end

  it 'encodes one source image and allows the generation strength to be configured' do
    payload = render(with: image_path, provider_options: { strength: 0.7 })

    expect(payload).to include(image: image.encoded, mode: 'image-to-image', strength: 0.7)
    expect(payload).not_to have_key(:aspect_ratio)
  end

  it 'maps a source image and mask to the inpaint request without a generation mode' do
    payload = render(model: edit_model, with: image_path, mask: image, provider_options: { grow_mask: 3 })

    expect(payload).to eq(prompt: 'A blue teapot', image: image.encoded, mask: image.encoded, grow_mask: 3)
    expect(render(model: edit_model, with: image_path)).not_to have_key(:mask)
  end

  it 'rejects missing or multiple source images and resizing during edits' do
    expect { render(model: edit_model) }.to raise_error(ArgumentError, /exactly one image/)
    expect { render(with: [image_path, image_path]) }.to raise_error(ArgumentError, /exactly one image/)
    expect { render(with: image_path, size: '1024x1024') }.to raise_error(ArgumentError, /cannot change dimensions/)
    expect { render(mask: image_path) }.to raise_error(RubyLLM::UnsupportedAttachmentError, /image mask/)
  end

  it 'rejects non-image attachments and image references on text-only models' do
    text = RubyLLM::Attachment.new(StringIO.new('Ruby'), filename: 'ruby.txt')

    expect { render(with: text) }.to raise_error(RubyLLM::UnsupportedAttachmentError)
    expect { render(with: image_path, model: 'stability.stable-image-core-v1:1') }
      .to raise_error(RubyLLM::UnsupportedAttachmentError, /image reference/)
  end

  it 'returns typed image bytes and detects their actual MIME type' do
    response = instance_double(Faraday::Response, body: { 'images' => [image.encoded], 'finish_reasons' => [nil] })

    result = protocol.parse_image_responses(response, model: model.id).first

    expect(result).to have_attributes(model: model.id, mime_type: 'image/png')
    expect(result.to_blob).to eq(image.content)
  end

  it 'reports filtered or empty image responses as provider errors' do
    filtered = instance_double(Faraday::Response, body: { 'finish_reasons' => ['Filter reason: prompt'] })
    empty = instance_double(Faraday::Response, body: { 'images' => [''] })

    expect { protocol.parse_image_responses(filtered, model: model.id) }
      .to raise_error(RubyLLM::Error, /Filter reason: prompt/) { |error| expect(error.response).to eq(filtered) }
    expect { protocol.parse_image_responses(empty, model: model.id) }.to raise_error(RubyLLM::Error, /no images/)
  end

  it 'signs image invocations and propagates configuration to the result' do
    response = instance_double(Faraday::Response, body: { 'images' => [image.encoded] })
    request = Struct.new(:headers).new({})
    allow(provider).to receive(:sign_headers).and_return('Authorization' => 'signed')
    allow(provider.connection).to receive(:post).and_yield(request).and_return(response)

    result = protocol.paint('A blue teapot', model: model.id, size: nil, provider_options: { output_format: 'webp' })

    expect(provider).to have_received(:sign_headers).with('POST', "/model/#{model.id}/invoke",
                                                          JSON.generate(prompt: 'A blue teapot', output_format: 'webp'))
    expect(request.headers).to include('Authorization' => 'signed')
    expect(result).to have_attributes(mime_type: 'image/png', config: provider.config)
  end

  it 'generates an image with Bedrock Stable Diffusion', :live do
    result = RubyLLM.paint('A blue teapot on a wooden table', model: model_for(:bedrock, :bedrock_image),
                                                              provider: :bedrock, size: '1:1')

    expect(result).to be_a(RubyLLM::Image)
    expect(result.mime_type).to eq(RubyLLM::Files::MimeType.for(StringIO.new(result.to_blob)))
    expect(result.to_blob.bytesize).to be > 1000
  end

  it 'inpaints a local image through a Bedrock inference profile', :live do
    result = RubyLLM.paint('A polished blue gemstone', model: model_for(:bedrock, :bedrock_image_edit),
                                                       provider: :bedrock, with: image_path, mask: image_path)

    expect(result).to be_a(RubyLLM::Image)
    expect(result.mime_type).to eq('image/png')
    expect(result.to_blob).to start_with("\x89PNG".b)
  end
end

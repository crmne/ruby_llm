# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Protocols::Mistral::Conversations::Images do
  include_context 'with configured RubyLLM'

  let(:model) { RubyLLM.models.find(model_for(:mistral), provider: :mistral) }
  let(:provider) { RubyLLM::Providers::Mistral.new(RubyLLM.config) }
  let(:protocol) { RubyLLM::Providers::Mistral::Conversations.new(provider, model) }

  it 'routes paint through Conversations while preserving the default chat protocol' do
    expect(provider.protocol_for(model, operation: :paint)).to eq(RubyLLM::Providers::Mistral::Conversations)
    expect(provider.protocol_for(model)).to be < RubyLLM::Providers::Mistral::ChatCompletions
    expect(protocol.render_image_payload('Red circle', model: model.id, size: nil)).to include(
      model: model.id, store: false, inputs: 'Red circle', tools: [{ type: 'image_generation' }]
    )
  end

  it 'downloads generated files from the documented content endpoint and detects their actual type' do
    data = { 'outputs' => [{ 'type' => 'message.output', 'content' => [
      { 'type' => 'tool_file', 'tool' => 'image_generation', 'file_id' => 'generated', 'file_type' => 'png' }
    ] }], 'usage' => { 'prompt_tokens' => 10, 'completion_tokens' => 3, 'connector_tokens' => 5 } }
    bytes = "\xFF\xD8\xFF\xE0\x00\x10JFIF\x00".b
    allow(provider.connection).to receive(:get).with('files/generated/content').and_return(
      instance_double(Faraday::Response, body: bytes)
    )
    image = protocol.parse_image_response(instance_double(Faraday::Response, body: data), model: model.id)
    expect(image.to_blob).to eq(bytes)
    expect(image.mime_type).to eq('image/jpeg')
    expect(image.tokens).to have_attributes(input: 15, output: 3)
  end

  it 'rejects image controls that the hosted tool cannot honor' do
    expect do
      protocol.render_image_payload('Circle', model: model.id, size: '1024x1024')
    end.to raise_error(ArgumentError, /size/)
    expect do
      protocol.render_image_payload('Circle', model: model.id, size: nil, count: 2)
    end.to raise_error(ArgumentError, /count/)
  end

  it 'generates and downloads an image through paint', :live do
    image = RubyLLM.paint('Generate one image of a small red circle on a white background.',
                          model: model_for(:mistral), provider: :mistral)
    expect(image.to_blob.bytesize).to be > 1000
    expect(image.mime_type).to start_with('image/')
    expect(image.tokens.input).to be_positive
    expect(image.tokens.output).to be_positive
  end
end

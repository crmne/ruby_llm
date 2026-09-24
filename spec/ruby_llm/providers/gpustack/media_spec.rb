# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::GPUStack::Media do
  let(:model) { model_for(:gpustack) }

  it 'sends remote videos inline, because clusters often cannot reach the internet' do
    stub_request(:get, 'https://example.com/clip.mp4')
      .to_return(body: 'video bytes', headers: { 'Content-Type' => 'video/mp4' })
    attachment = RubyLLM::Attachment.new('https://example.com/clip.mp4')

    content = described_class.format_content('Describe this clip', [attachment])

    data_url = "data:video/mp4;base64,#{Base64.strict_encode64('video bytes')}"
    expect(content).to eq(
      [
        { type: 'text', text: 'Describe this clip' },
        { type: 'video_url', video_url: { url: data_url } }
      ]
    )
  end

  it 'encodes local video attachments as data URLs' do
    attachment = RubyLLM::Attachment.new(StringIO.new('video bytes'), filename: 'clip.mp4')

    content = described_class.format_content(nil, [attachment])

    expect(content).to eq(
      [{ type: 'video_url', video_url: { url: "data:video/mp4;base64,#{Base64.strict_encode64('video bytes')}" } }]
    )
  end

  it 'accepts video attachments through the public chat API' do
    stub_request(:get, 'https://example.com/clip.mp4')
      .to_return(body: 'video bytes', headers: { 'Content-Type' => 'video/mp4' })
    data_url = "data:video/mp4;base64,#{Base64.strict_encode64('video bytes')}"

    request = stub_request(:post, 'http://localhost:11444/v1/chat/completions')
              .with do |http_request|
      payload = JSON.parse(http_request.body)
      payload['messages'] == [
        { 'role' => 'user', 'content' => [
          { 'type' => 'text', 'text' => 'Describe this clip' },
          { 'type' => 'video_url', 'video_url' => { 'url' => data_url } }
        ] }
      ]
    end.to_return_json(body: { choices: [{ message: { role: 'assistant', content: 'A Ruby tutorial.' } }] })

    context = RubyLLM.context { |config| config.gpustack_api_base = 'http://localhost:11444/v1' }
    response = context.chat(model:, provider: :gpustack).ask('Describe this clip', with: 'https://example.com/clip.mp4')

    expect(request).to have_been_requested.once
    expect(response.content).to eq('A Ruby tutorial.')
  end
end

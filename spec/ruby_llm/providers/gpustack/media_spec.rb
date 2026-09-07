# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::GPUStack::Media do
  let(:model) { model_for(:gpustack) }

  it 'passes remote videos to the backend without downloading them' do
    attachment = RubyLLM::Attachment.new('https://example.com/clip.mp4')

    content = described_class.format_content('Describe this clip', [attachment])

    expect(content).to eq(
      [
        { type: 'text', text: 'Describe this clip' },
        { type: 'video_url', video_url: { url: 'https://example.com/clip.mp4' } }
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
    request = stub_request(:post, 'http://localhost:11444/v1/chat/completions')
              .with do |http_request|
      payload = JSON.parse(http_request.body)
      payload['messages'] == [
        { 'role' => 'user', 'content' => [
          { 'type' => 'text', 'text' => 'Describe this clip' },
          { 'type' => 'video_url', 'video_url' => { 'url' => 'https://example.com/clip.mp4' } }
        ] }
      ]
    end.to_return_json(body: { choices: [{ message: { role: 'assistant', content: 'A Ruby tutorial.' } }] })

    context = RubyLLM.context { |config| config.gpustack_api_base = 'http://localhost:11444/v1' }
    response = context.chat(model:, provider: :gpustack).ask('Describe this clip', with: 'https://example.com/clip.mp4')

    expect(request).to have_been_requested.once
    expect(response.content).to eq('A Ruby tutorial.')
  end
end

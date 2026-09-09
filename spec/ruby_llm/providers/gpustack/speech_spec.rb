# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::GPUStack::Speech do
  include_context 'with configured RubyLLM'

  it 'requests the vLLM binary stream with PCM as its default format' do
    model = model_for(:gpustack)
    request = stub_request(:post, 'http://localhost:11444/v1/audio/speech')
              .with(body: { model:, input: 'Hello', voice: 'Vivian', stream: true, response_format: 'pcm' })
              .to_return(body: 'audio bytes', headers: { 'content-type' => 'application/octet-stream' })
    chunks = []

    speech = RubyLLM.speak('Hello', model:, provider: :gpustack, voice: 'Vivian') { |chunk| chunks << chunk }

    expect(request).to have_been_requested.once
    expect(speech.format).to eq('pcm')
    expect(chunks.first.format).to eq('pcm')
    expect(chunks.map(&:data).join).to eq(speech.data)
  end
end

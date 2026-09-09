# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::XAI::Speech do
  it 'rejects timestamp JSON responses before starting an audio stream' do
    config = RubyLLM::Configuration.new
    config.xai_api_key = 'test'
    provider = RubyLLM::Providers::XAI.new(config)
    protocol = RubyLLM::Providers::XAI::Responses.new(provider, model_for(:xai, :speech))

    expect do
      protocol.speak('Hello', model: model_for(:xai, :speech), voice: 'eve', format: 'mp3',
                              provider_options: { with_timestamps: true }) { |chunk| raise "Unexpected: #{chunk}" }
    end.to raise_error(ArgumentError, /does not accept with_timestamps/)
  end

  it 'streams speech and retains the complete audio through the public API', :live do
    chunks = []
    speech = RubyLLM.speak(
      'Ruby makes it easy to build useful AI applications. Stream each piece of audio as it arrives, ' \
      'while keeping the complete recording for later.',
      model: model_for(:xai, :speech), provider: :xai, voice: 'eve', format: :mp3
    ) { |chunk| chunks << chunk }

    expect(chunks).not_to be_empty
    expect(chunks).to all(be_a(RubyLLM::SpeechChunk))
    expect(chunks.map(&:data).join).to eq(speech.to_blob)
    expect(speech.to_blob.bytesize).to be > 1000
    expect(speech.mime_type).to eq('audio/mpeg')
  end
end

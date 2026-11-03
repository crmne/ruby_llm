# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::XAI::Transcription do
  let(:audio) { File.expand_path('../../../fixtures/ruby.wav', __dir__) }
  let(:context) { RubyLLM.context { |config| config.xai_api_key = 'test' } }

  def stub_stt
    stub_request(:post, 'https://api.x.ai/v1/stt')
      .with { |request| yield request.body.scan(/(?<!file)name="([^"]+)"/).flatten, request.body }
      .to_return_json(body: { text: 'Ruby' })
  end

  it 'sends the real model id for the grok-stt routing name, before the file' do
    request = stub_stt do |fields, body|
      fields == %w[model file] && body.include?("\r\n\r\ngrok-voice-transcribe-2.0\r\n")
    end

    context.transcribe(audio, model: 'grok-stt', provider: :xai)

    expect(request).to have_been_requested
  end

  it 'counts the reported duration as billed audio seconds' do
    response = Struct.new(:body).new({ 'text' => 'Ruby', 'duration' => 3.2 })

    transcription = described_class.parse_transcription_response(response, model: 'grok-voice-transcribe-2.0')

    expect(transcription.tokens.audio_seconds).to eq(3.2)
  end

  it 'sends any other model as given' do
    payload = described_class.render_transcription_payload(:file, model: 'grok-voice-transcribe-3.0', language: nil)

    expect(payload).to eq(model: 'grok-voice-transcribe-3.0', file: :file)
  end

  it 'lets a String option replace the model and keeps the file last' do
    payload = described_class.render_transcription_payload(
      :file, model: 'grok-stt', language: nil, provider_options: { 'file' => 'x', 'model' => 'other', keyterm: 'Ruby' }
    )

    expect(payload.to_a).to eq([[:model, 'other'], [:keyterm, 'Ruby'], %i[file file]])
  end

  it 'turns on diarization for empty speaker_names' do
    payload = described_class.render_transcription_payload(:file, model: 'grok-stt', language: 'en', speaker_names: [])

    expect(payload).to include(language: 'en', diarize: true)
  end
end

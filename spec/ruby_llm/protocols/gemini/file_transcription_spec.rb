# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Protocols::Gemini::FileTranscription do
  include_context 'with configured RubyLLM'

  let(:audio_path) { File.expand_path('../../../fixtures/ruby.wav', __dir__) }
  let(:gemini) { RubyLLM::Providers::Gemini.new(RubyLLM.config) }
  let(:vertex) { RubyLLM::Providers::VertexAI.new(RubyLLM.config) }
  let(:interactions) do
    RubyLLM::Protocols::Interactions.new(gemini, RubyLLM.models.find(model_for(:gemini, :dedicated_transcription)))
  end
  let(:transcription) { RubyLLM::Providers::VertexAI::Transcription.new(vertex) }

  it 'routes only dedicated transcription models to their dedicated protocols' do
    expect(gemini.protocol_for(RubyLLM.models.find(model_for(:gemini, :dedicated_transcription)),
                               operation: :transcribe))
      .to eq(RubyLLM::Protocols::Interactions)
    expect(vertex.protocol_for(RubyLLM.models.find(model_for(:vertexai, :dedicated_transcription)),
                               operation: :transcribe))
      .to eq(RubyLLM::Providers::VertexAI::Transcription)
    expect(gemini.protocol_for(RubyLLM.models.find(model_for(:gemini)), operation: :transcribe))
      .to eq(gemini.protocols[:gemini])
    expect(vertex.protocol_for(RubyLLM.models.find(model_for(:vertexai)), operation: :transcribe))
      .to eq(vertex.protocols[:gemini])
    expect(gemini.protocol_for(RubyLLM.models.find(model_for(:gemini, :dedicated_transcription))))
      .to eq(gemini.protocols[:gemini])
  end

  it 'renders Interactions verbatim metadata in mode and preserves inline audio bytes' do
    attachment = RubyLLM::Attachment.new(audio_path)
    options = interactions.render_transcription_options(timestamps: :word)
    payload = interactions.render_transcription_payload(
      attachment, model: model_for(:gemini, :dedicated_transcription), language: 'en-US',
                  speaker_names: ['Speaker'], prompt: nil, provider_options: options
    )

    expect(payload[:generation_config]).to eq(transcription_config: {
                                                language_codes: ['en-US'], mode: {
                                                  type: 'verbatim', diarization_mode: 'speaker',
                                                  timestamp_granularities: ['word']
                                                }
                                              })
    expect(payload[:store]).to be(false)
    expect(Base64.strict_decode64(payload.dig(:input, 0, :data))).to eq(File.binread(audio_path))
  end

  it 'renders Vertex transcription configuration without a generated text prompt' do
    attachment = RubyLLM::Attachment.new(audio_path)
    options = transcription.render_transcription_options(timestamps: :word)
    payload = transcription.render_transcription_payload(
      attachment, language: 'en-US', speaker_names: ['Speaker'], prompt: nil, provider_options: options
    )

    expect(payload[:generationConfig]).to eq(audioTranscriptionConfig: {
                                               languageCodes: ['en-US'], diarization: true, wordTimestamp: true
                                             })
    expect(payload.dig(:contents, 0, :parts).size).to eq(1)
    expect(payload.dig(:contents, 0, :parts, 0)).to have_key(:inline_data)
  end

  it 'preserves Interactions speaker-only annotations without fabricating timing' do
    data = { 'status' => 'completed', 'steps' => [{ 'type' => 'model_output', 'content' => [
      { 'type' => 'text', 'text' => 'Hello', 'annotations' => [
        { 'type' => 'word_info', 'text' => 'Hello', 'speaker' => 'spk:0' }
      ] }
    ] }], 'usage' => { 'total_input_tokens' => 14, 'total_output_tokens' => 0 } }
    response = instance_double(Faraday::Response, body: data)

    result = interactions.parse_transcription_response(response, model: model_for(:gemini, :dedicated_transcription))

    expect(result.text).to eq('Hello')
    expect(result.words).to eq([{ 'word' => 'Hello', 'speaker' => 'spk:0' }])
    expect(result.tokens).to have_attributes(input: 14, output: 0)
    expect(result.duration).to be_nil
  end

  it 'joins Vertex text once and preserves separate speakers with numeric word offsets' do
    parts = [{ 'text' => 'Hello. ', 'audioTranscription' => {
      'text' => 'Hello. ', 'speakerLabel' => 'spk:0',
      'words' => [{ 'word' => 'Hello.', 'startOffset' => '0s', 'endOffset' => '0.500s' }]
    } }, { 'audioTranscription' => { 'text' => 'Hi.', 'speakerLabel' => 'spk:1' } }]
    response = instance_double(Faraday::Response, body: { 'candidates' => [{ 'content' => { 'parts' => parts } }] })

    result = transcription.send(:parse_transcription_response, response,
                                model: model_for(:vertexai, :dedicated_transcription))

    expect(result.text).to eq('Hello. Hi.')
    expect(result.segments.map { |segment| segment['speaker'] }).to eq(['spk:0', 'spk:1'])
    expect(result.words).to eq([{ 'word' => 'Hello.', 'speaker' => 'spk:0', 'start' => 0.0, 'end' => 0.5 }])
    expect(result.tokens.input).to be_nil
  end

  it 'rejects incompatible custom vocabulary and timestamp options before requesting an interaction' do
    expect do
      RubyLLM.transcribe(audio_path, model: model_for(:gemini, :dedicated_transcription), provider: :gemini,
                                     timestamps: :word, prompt: 'RubyLLM')
    end.to raise_error(ArgumentError, /custom vocabulary cannot be combined/)
  end

  it 'rejects unknown granularities and unsupported reference clips instead of ignoring them' do
    expect { interactions.render_transcription_options(timestamps: :segment) }
      .to raise_error(ArgumentError, /must be word/)
    expect do
      RubyLLM.transcribe(audio_path, model: model_for(:vertexai, :dedicated_transcription), provider: :vertexai,
                                     speaker_references: [audio_path])
    end.to raise_error(ArgumentError, /speaker references/)
  end

  it 'rejects non-global Vertex dedicated models before the request' do
    RubyLLM.config.vertexai_location = 'us-central1'

    expect do
      RubyLLM.transcribe(audio_path, model: model_for(:vertexai, :dedicated_transcription), provider: :vertexai)
    end.to raise_error(ArgumentError, /requires vertexai_location/)
  end
end

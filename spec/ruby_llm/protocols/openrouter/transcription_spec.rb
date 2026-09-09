# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Protocols::OpenRouter::Transcription do
  let(:context) { RubyLLM.context { |config| config.openrouter_api_key = 'test' } }
  let(:model) { model_for(:openrouter, :diarization) }
  let(:audio) { 'spec/fixtures/ruby.wav' }

  it 'sends JSON diarization options and preserves segment and word speakers with actual cost' do
    request = stub_request(:post, 'https://openrouter.ai/api/v1/audio/transcriptions').with do |req|
      payload = JSON.parse(req.body)
      expect(payload.dig('input_audio', 'data')).to eq(Base64.strict_encode64(File.binread(audio)))
      expect(payload['response_format']).to eq('verbose_json')
      expect(payload.dig('provider', 'options', 'azure', 'diarization')).to eq('enabled' => true)
      expect(payload.dig('provider', 'options', 'deepgram')).to eq('diarize' => true)
      expect(payload.dig('provider', 'options', 'azure', 'custom')).to eq('value')
    end.to_return_json(body: { text: 'Ruby.', duration: 4, segments: [{ text: 'Ruby.', speaker: 0 }],
                               words: [{ word: 'Ruby.', speaker: 0 }], usage: { seconds: 4, cost: 0.0001 } })
    result = context.transcribe(audio, model:, provider: :openrouter, speaker_names: [],
                                       provider_options: { provider: { options: { azure: { custom: 'value' } } } })
    expect(result.text).to eq('Ruby.')
    expect(result.segments.first['speaker']).to eq(0)
    expect(result.words.first['speaker']).to eq(0)
    expect(result.cost.total).to eq(0.0001)
    expect(request).to have_been_requested.once
  end

  it 'rejects unsupported speaker identity, prompt and output options before sending audio' do
    [{ speaker_names: ['Alice'] }, { speaker_references: [audio] }, { prompt: 'Ruby' }, { format: :srt },
     { speaker_names: [], format: :json }].each do |options|
      expect { context.transcribe(audio, model:, provider: :openrouter, **options) }.to raise_error(ArgumentError)
    end
    expect(a_request(:post, 'https://openrouter.ai/api/v1/audio/transcriptions')).not_to have_been_made
  end

  it 'transcribes a real recording with speaker labels and reported duration and cost', :live do
    result = RubyLLM.transcribe(audio, model:, provider: :openrouter, speaker_names: [],
                                       provider_options: { timestamp_granularities: %w[segment word] })
    expect(result.text).to include('Ruby')
    expect(result.segments.map { |segment| segment['speaker'] }).to include(0)
    expect(result.words.map { |word| word['speaker'] }).to include(0)
    expect(result.duration).to be > 0
    expect(result.cost.total).to be > 0
  end
end

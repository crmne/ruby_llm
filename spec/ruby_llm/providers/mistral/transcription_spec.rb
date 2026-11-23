# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::Mistral::Transcription do
  let(:protocol) { RubyLLM::Providers::Mistral::ChatCompletions.allocate }
  let(:model) { model_for(:mistral, :transcription) }

  def transcribe_events(events)
    payload = { model: model, stream: 'true' }
    allow(protocol).to receive(:stream_events).with('audio/transcriptions', payload) do |&block|
      events.each(&block)
    end
    chunks = []
    result = protocol.send(:stream_transcription, { model: model }, model:) { |chunk| chunks << chunk }
    [result, chunks]
  end

  it 'streams Mistral text and preserves the final language, audio duration, and usage' do
    events = [
      { 'type' => 'transcription.language', 'audio_language' => 'en' },
      { 'type' => 'transcription.text.delta', 'text' => 'Hello, ' },
      { 'type' => 'transcription.text.delta', 'text' => 'Ruby.' },
      { 'type' => 'transcription.done', 'text' => 'Hello, Ruby.', 'language' => 'en',
        'usage' => { 'prompt_tokens' => 8, 'completion_tokens' => 4, 'prompt_audio_seconds' => 3 } }
    ]

    result, chunks = transcribe_events(events)

    expect(chunks.filter_map(&:delta).join).to eq('Hello, Ruby.')
    expect(chunks.last).to be_done
    expect(chunks.last.raw).to eq(events.last)
    expect(result).to have_attributes(text: 'Hello, Ruby.', language: 'en', duration: 3)
    expect(result.tokens).to have_attributes(input: nil, output: nil, audio_seconds: 3)
  end

  def transcription_with(usage)
    body = { 'model' => model, 'text' => 'Hello, Ruby.', 'language' => 'en', 'segments' => [], 'usage' => usage }
    protocol.send(:parse_transcription_response, instance_double(Faraday::Response, body:), model:)
  end

  it 'counts the audio seconds Mistral bills and not the tokens it reports next to them' do
    transcription = transcription_with('prompt_audio_seconds' => 120, 'prompt_tokens' => 3,
                                       'completion_tokens' => 13, 'total_tokens' => 3016)

    expect(transcription.duration).to eq(120)
    expect(transcription.tokens).to have_attributes(input: nil, output: nil, audio_seconds: 120)
  end

  it 'prices a transcription with the price of a second of audio alone' do
    RubyLLM.config.price model, provider: :mistral, audio_seconds: 0.0035 / 60 * 1_000_000
    tokens = transcription_with('prompt_audio_seconds' => 120, 'prompt_tokens' => 3, 'completion_tokens' => 13).tokens

    expect(RubyLLM.models.find(model, provider: :mistral).cost_for(tokens).total).to be_within(1e-9).of(0.007)
  end

  it 'keeps the token counts of a reply without billed audio seconds' do
    transcription = transcription_with('prompt_tokens' => 3, 'completion_tokens' => 13)

    expect(transcription.tokens).to have_attributes(input: 3, output: 13, audio_seconds: nil)
  end

  it 'leaves audio seconds to the shared rule when Mistral reports none' do
    response = instance_double(Faraday::Response, body: { 'text' => 'Hello.', 'duration' => 2.5 })

    transcription = protocol.send(:parse_transcription_response, response, model:)

    expect(transcription.tokens.audio_seconds).to eq(2.5)
  end

  it 'streams diarized segments without duplicating the final segments' do
    segment = { 'text' => 'Hello.', 'start' => 0.0, 'end' => 1.0, 'speaker_id' => 'speaker_0' }
    events = [
      segment.merge('type' => 'transcription.segment'),
      { 'type' => 'transcription.done', 'text' => 'Hello.', 'segments' => [segment], 'usage' => {} }
    ]

    result, chunks = transcribe_events(events)

    expect(chunks.first.segment).to eq(segment)
    expect(result.segments).to eq([segment])
  end

  it 'preserves segments reported only by the final event' do
    segment = { 'text' => 'Hello.', 'start' => 0.0, 'end' => 1.0 }
    events = [{ 'type' => 'transcription.done', 'text' => 'Hello.', 'segments' => [segment], 'usage' => {} }]

    result, = transcribe_events(events)

    expect(result.segments).to eq([segment])
  end
end

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
    expect(result.tokens).to have_attributes(input: 8, output: 4)
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

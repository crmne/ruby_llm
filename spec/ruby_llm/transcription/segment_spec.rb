# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Transcription::Segment do
  let(:segment) { described_class.new('text' => 'Hello', 'speaker' => 'A', 'start' => 1.5, 'end' => 2.0, 'id' => 7) }

  it 'reads what providers share' do
    expect(segment).to have_attributes(text: 'Hello', speaker: 'A', start: 1.5, end: 2.0)
  end

  it 'reads a word and a Deepgram utterance as text' do
    expect(described_class.new('word' => 'Hi').text).to eq('Hi')
    expect(described_class.new('transcript' => 'Hi there').text).to eq('Hi there')
  end

  it 'reads an ElevenLabs speaker id as the speaker' do
    expect(described_class.new('speaker_id' => 'speaker_0').speaker).to eq('speaker_0')
  end

  it 'keeps Hash reads working' do
    expect(segment['id']).to eq(7)
    expect(segment[:speaker]).to eq('A')
    expect(segment.fetch('text', nil)).to eq('Hello')
    expect(segment.fetch('missing', nil)).to be_nil
    expect { segment.fetch('missing') }.to raise_error(KeyError)
    expect(segment).to have_key('id').and(have_key(:text))
    expect(segment).to include('start' => 1.5)
    expect(segment.key?('missing')).to be(false)
  end

  it 'compares equal to the Hash it holds' do
    expect(segment.to_h).to include('id' => 7)
    expect(segment).to eq(segment.to_h)
    expect(segment).not_to eq('text' => 'Bye')
    expect(segment).not_to eq(7)
  end

  it 'wraps a list once and leaves nil alone' do
    wrapped = described_class.wrap([{ 'text' => 'Hi' }])

    expect(described_class.wrap(wrapped).first).to be_a(described_class).and have_attributes(text: 'Hi')
    expect(described_class.wrap(nil)).to be_nil
  end

  it 'inspects on one line' do
    expect(segment.inspect).to include('text: "Hello"', 'end: 2.0')
  end

  describe 'on results' do
    it 'wraps the segments and words of a Transcription' do
      transcription = RubyLLM::Transcription.new(text: 'Hi', model: 'gpt-4o-transcribe-diarize',
                                                 segments: [{ 'text' => 'Hi' }], words: [{ 'word' => 'Hi' }])

      expect(transcription.segments.first).to be_a(described_class).and have_attributes(text: 'Hi')
      expect(transcription.words.first).to be_a(described_class).and have_attributes(text: 'Hi')
    end

    it 'keeps nil when the provider returned neither' do
      expect(RubyLLM::Transcription.new(text: 'Hi', model: 'gpt-4o-transcribe-diarize'))
        .to have_attributes(segments: nil, words: nil)
    end

    it 'wraps the segment of a TranscriptionChunk' do
      chunk = RubyLLM::TranscriptionChunk.new(type: :segment, segment: { 'speaker' => 'A', 'text' => 'Hi' })

      expect(chunk.segment).to be_a(described_class).and have_attributes(speaker: 'A')
      expect(RubyLLM::TranscriptionChunk.new(type: :delta, delta: 'Hi')).not_to be_segment
    end
  end
end

# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::TranscriptionChunk do
  def chunk_from(data)
    RubyLLM::Protocols::ChatCompletions::Transcription.build_transcription_chunk(data)
  end

  {
    'transcript.text.delta' => :delta,
    'transcript.text.segment' => :segment,
    'transcript.text.done' => :done
  }.each do |wire, type|
    it "maps #{wire} to #{type.inspect}" do
      expect(chunk_from('type' => wire).type).to eq(type)
    end
  end

  it 'keeps the text of a delta' do
    expect(chunk_from('type' => 'transcript.text.delta', 'delta' => 'Hi').delta).to eq('Hi')
  end

  it 'keeps the segment and the final text on their chunks' do
    segment = chunk_from('type' => 'transcript.text.segment', 'text' => 'Hi')
    done = chunk_from('type' => 'transcript.text.done', 'text' => 'Hi')

    expect(segment.segment).to eq('text' => 'Hi')
    expect(done).to be_done
    expect(done.text).to eq('Hi')
  end

  it 'leaves the type of an event RubyLLM does not normalize as nil' do
    chunk = chunk_from('type' => 'transcript.text.logprobs')

    expect(chunk.type).to be_nil
    expect(chunk.raw).to eq('type' => 'transcript.text.logprobs')
  end

  it 'maps Mistral events to the same types' do
    protocol = RubyLLM::Providers::Mistral::Transcription

    expect(protocol.build_transcription_chunk('type' => 'transcription.text.delta', 'text' => 'Hi').type).to eq(:delta)
  end

  it 'names every type with a Symbol' do
    expect([described_class::DELTA, described_class::PARTIAL, described_class::SEGMENT, described_class::DONE])
      .to eq(%i[delta partial segment done])
  end

  it 'answers partial? and done? from the type' do
    expect(described_class.new(type: :partial)).to be_partial
    expect(described_class.new(type: :done)).to be_done
    expect(described_class.new(type: :delta)).not_to be_partial
  end
end

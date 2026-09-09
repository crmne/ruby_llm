# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::GPUStack::Transcription do
  let(:protocol) { RubyLLM::Providers::GPUStack::ChatCompletions.allocate }
  let(:model) { model_for(:gpustack) }

  def transcribe_events(events)
    payload = { model: model, stream: 'true', stream_include_usage: 'true' }
    allow(protocol).to receive(:stream_events).with('audio/transcriptions', payload) do |&block|
      events.each(&block)
    end

    chunks = []
    result = protocol.send(:stream_transcription, { model: model }, model: model) { |chunk| chunks << chunk }
    [result, chunks]
  end

  it 'streams vLLM text and retains a separate final usage event' do
    events = [
      { 'choices' => [{ 'delta' => { 'role' => 'assistant', 'content' => '' }, 'finish_reason' => nil }] },
      { 'choices' => [{ 'delta' => { 'content' => 'Hello, ' }, 'finish_reason' => nil }] },
      { 'choices' => [{ 'delta' => { 'content' => 'Ruby.' }, 'finish_reason' => 'stop' }] },
      { 'choices' => [], 'usage' => { 'prompt_tokens' => 20, 'completion_tokens' => 4 } }
    ]

    result, chunks = transcribe_events(events)

    expect(chunks.filter_map(&:delta).join).to eq('Hello, Ruby.')
    expect(chunks.last).to be_done
    expect(chunks.last.raw).to eq(events.last)
    expect(result.text).to eq('Hello, Ruby.')
    expect(result.tokens.input).to eq(20)
    expect(result.tokens.output).to eq(4)
  end

  it 'returns the transcript when vLLM does not report usage' do
    events = [
      { 'choices' => [{ 'delta' => { 'content' => 'Good morning.' }, 'finish_reason' => nil }] },
      { 'choices' => [{ 'delta' => {}, 'finish_reason' => 'stop' }] }
    ]

    result, chunks = transcribe_events(events)

    expect(result.text).to eq('Good morning.')
    expect(chunks.last).to be_done
    expect(result.tokens.input).to be_nil
  end

  it 'preserves typed transcript and speaker events from compatible backends' do
    segment = { 'type' => 'transcript.text.segment', 'text' => 'Hello.', 'speaker' => 'S01', 'start' => 0, 'end' => 1 }
    events = [
      segment,
      { 'type' => 'transcript.text.done', 'text' => 'Hello.',
        'usage' => { 'input_tokens' => 10, 'output_tokens' => 2 } }
    ]

    result, chunks = transcribe_events(events)

    expect(chunks.first).to be_segment
    expect(chunks.first.raw).to eq(segment)
    expect(result.text).to eq('Hello.')
    expect(result.segments).to eq([segment.except('type')])
    expect(result.tokens.input).to eq(10)
  end
end

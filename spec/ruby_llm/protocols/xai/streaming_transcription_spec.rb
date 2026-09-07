# frozen_string_literal: true

require 'spec_helper'
require_relative '../../../support/websocket_cassette'

RSpec.describe RubyLLM::Protocols::XAI::StreamingTranscription do
  include WebsocketCassette

  let(:config) do
    RubyLLM::Configuration.new.tap { |config| config.xai_api_key = 'test' }
  end
  let(:provider) { RubyLLM::Providers::XAI.new(config) }
  let(:protocol) { RubyLLM::Providers::XAI::Responses.new(provider, model_for(:xai, :transcription)) }
  let(:audio_path) { File.expand_path('../../../fixtures/ruby.wav', __dir__) }
  let(:segment) do
    { 'type' => 'transcript.partial', 'text' => 'Ruby is useful.', 'start' => 0.0, 'duration' => 1.0,
      'words' => [{ 'text' => 'Ruby', 'start' => 0.0, 'end' => 0.3, 'speaker' => 0 }],
      'is_final' => true, 'speech_final' => false, 'language' => 'en' }
  end

  it 'deduplicates repeated finalized segments while keeping interim revisions separate' do
    segments = []
    chunks = []
    protocol.process_transcription_segment(segment.merge('is_final' => false), segments) { |chunk| chunks << chunk }
    protocol.process_transcription_segment(segment, segments) { |chunk| chunks << chunk }
    protocol.process_transcription_segment(segment.merge('speech_final' => true), segments) { |chunk| chunks << chunk }
    protocol.process_transcription_segment({ 'type' => 'transcript.done', 'text' => '', 'duration' => 1.0 },
                                           segments) { |chunk| chunks << chunk }

    expect(chunks.map(&:type)).to eq([RubyLLM::TranscriptionChunk::PARTIAL, RubyLLM::TranscriptionChunk::SEGMENT])
    expect(chunks.first).to have_attributes(partial?: true, text: 'Ruby is useful.', delta: nil)
    expect(chunks.last).to have_attributes(delta: 'Ruby is useful.', raw: segment)
    expect(segments.size).to eq(1)
    expect(segments.first['words'].first['speaker']).to eq(0)
  end

  it 'keeps an intentionally repeated phrase at a different audio position' do
    segments = []
    chunks = []
    [segment.except('words'), segment.except('words').merge('start' => 2.0)].each do |event|
      protocol.process_transcription_segment(event, segments) { |chunk| chunks << chunk }
    end

    expect(chunks.filter_map(&:delta).join).to eq('Ruby is useful. Ruby is useful.')
    expect(segments.map { |item| item['start'] }).to eq([0.0, 2.0])
  end

  it 'derives the wire encoding and sample rate from WAV data and preserves repeated key terms' do
    audio = RubyLLM::Transcription::WavAudio.new(File.binread(audio_path))
    url = protocol.streaming_transcription_url({ language: 'en', keyterm: %w[Ruby Rails], diarize: true }, audio:)
    params = URI.decode_www_form(URI(url).query)

    expect(url).to start_with('wss://api.x.ai/v1/stt?')
    expect(params).to include(%w[encoding pcm], %w[sample_rate 24000], %w[interim_results true],
                              %w[keyterm Ruby], %w[keyterm Rails], %w[diarize true])
  end

  it 'retains finalized text, words, language and duration when completion contains no text' do
    segments = [protocol.parse_transcription_segment(segment)]
    completed = [{ 'type' => 'transcript.done', 'text' => '', 'words' => [], 'duration' => 3.7 }]
    result = protocol.build_streamed_transcription(segments, completed,
                                                   model: model_for(:xai, :transcription), language: nil)

    expect(result).to have_attributes(text: 'Ruby is useful.', language: 'en', duration: 3.7)
    expect(result.words).to eq(segment['words'])
  end

  it 'rejects unsupported WAV encodings before opening a socket' do
    audio = instance_double(RubyLLM::Transcription::WavAudio, encoding: 3, bits_per_sample: 32)

    expect { protocol.streaming_transcription_url({}, audio:) }
      .to raise_error(ArgumentError, /16-bit PCM or 8-bit G.711 WAV/)
  end

  it 'keeps completion events separate for each audio channel and surfaces server errors' do
    segments = []
    completed = []
    ready = Queue.new
    done = { 'type' => 'transcript.done', 'text' => '', 'duration' => 1.0, 'channel_index' => 0 }
    [done, done, done.merge('channel_index' => 1)].each do |event|
      protocol.process_transcription_event(event, segments, completed, ready) { |chunk| chunk }
    end

    expect(completed.map { |event| event['channel_index'] }).to eq([0, 1])
    expect do
      protocol.process_transcription_event({ 'type' => 'error', 'message' => 'Invalid audio' },
                                           segments, completed, ready) { |chunk| chunk }
    end.to raise_error(RubyLLM::Error, 'Invalid audio')
  end

  it 'streams transcription through the public API with typed chunks and word timing', :live do
    with_websocket_cassette('transcription_xai', key: 'XAI_API_KEY') do
      chunks = []
      result = RubyLLM.transcribe(audio_path, model: model_for(:xai, :transcription), provider: :xai,
                                              language: 'en', speaker_names: ['Speaker']) { |chunk| chunks << chunk }

      expect(result.text).to include('Ruby', 'developer happiness')
      expect(result.duration).to be > 3
      expect(result.words).not_to be_empty
      expect(result.words).to all(include('start', 'end'))
      expect(chunks).to include(have_attributes(partial?: true))
      expect(chunks.filter_map(&:delta).join).to eq(result.text)
      expect(chunks.last).to have_attributes(done?: true, text: result.text)
      expect(result.ruby_llm_usage_entries.map(&:status)).to eq([:succeeded])
    end
  end
end

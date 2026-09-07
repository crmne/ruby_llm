# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Protocols::ElevenLabs::StreamingTranscription do
  include_context 'with configured RubyLLM'

  let(:provider) { RubyLLM::Providers::ElevenLabs.new(RubyLLM.config) }
  let(:protocol) { RubyLLM::Protocols::ElevenLabs.new(provider) }
  let(:model) { model_for(:elevenlabs, :websocket_transcription) }

  def committed(text, start: 0)
    [
      { 'message_type' => 'committed_transcript', 'text' => text },
      { 'message_type' => 'committed_transcript_with_timestamps', 'text' => text, 'language_code' => 'en',
        'words' => [{ 'text' => text, 'start' => start, 'end' => start + 1 }] }
    ]
  end

  it 'appends committed groups and retains their word timestamps' do
    socket = instance_double(RubyLLM::Transport::WebsocketConnection, close: nil)
    allow(RubyLLM::Transport::WebsocketConnection).to receive(:open).and_yield(socket)
    allow(socket).to receive(:each_message) do |&block|
      (committed('First sentence.') + committed('Second sentence.', start: 20)).each do |event|
        block.call(JSON.generate(event))
      end
    end
    chunks = []

    transcripts = protocol.collect_transcription('wss://example.com', nil, 2) { |chunk| chunks << chunk }
    audio = instance_double(RubyLLM::Transcription::WavAudio, duration: 25)
    result = protocol.build_streaming_transcription(transcripts, audio, model:)

    expect(chunks.filter_map(&:delta).join).to eq('First sentence. Second sentence.')
    expect(result.text).to eq('First sentence. Second sentence.')
    expect(result.words.map { |word| word['start'] }).to eq([0, 20])
    expect(result).to have_attributes(language: 'en', duration: 25)
    expect(socket).to have_received(:close).once
  end

  it 'does not turn a truncated set of committed groups into a successful result' do
    socket = instance_double(RubyLLM::Transport::WebsocketConnection)
    allow(RubyLLM::Transport::WebsocketConnection).to receive(:open).and_yield(socket)
    allow(socket).to receive(:each_message).and_yield(JSON.generate(committed('First sentence.').last))

    expect { protocol.collect_transcription('wss://example.com', nil, 2) { nil } }
      .to raise_error(RubyLLM::Error, /before its committed transcript/)
  end

  it 'commits an exact twenty-second input once without dropping or duplicating audio' do
    data = ('audio'.b * 32_000)
    audio = instance_double(RubyLLM::Transcription::WavAudio, sample_rate: 8000, channels: 1, bits_per_sample: 8, data:)
    socket = instance_double(RubyLLM::Transport::WebsocketConnection)
    frames = []
    allow(socket).to receive(:send_text) { |frame| frames << JSON.parse(frame) }
    commits = Queue.new
    commits << true

    protocol.send_transcription_audio(socket, audio, commits)

    expect(frames.map { |frame| Base64.strict_decode64(frame.fetch('audio_base_64')) }.join).to eq(data)
    expect(frames.count { |frame| frame['commit'] }).to eq(1)
    expect(frames.last['commit']).to be(true)
  end

  it 'waits for every commit acknowledgement before sending the next group' do
    data = 'a'.b * 200_000
    audio = instance_double(RubyLLM::Transcription::WavAudio, sample_rate: 8000, channels: 1, bits_per_sample: 8, data:)
    socket = instance_double(RubyLLM::Transport::WebsocketConnection)
    acknowledgements = instance_double(Thread::Queue)
    frames = []
    commit_sizes = []
    allow(socket).to receive(:send_text) { |frame| frames << JSON.parse(frame) }
    allow(acknowledgements).to receive(:pop) do
      expect(frames.last['commit']).to be(true)
      commit_sizes << frames.sum { |frame| Base64.strict_decode64(frame.fetch('audio_base_64')).bytesize }
    end

    protocol.send_transcription_audio(socket, audio, acknowledgements)

    expect(frames.count { |frame| frame['commit'] }).to eq(2)
    expect(commit_sizes).to eq([160_000, 200_000])
    expect(frames.map { |frame| Base64.strict_decode64(frame.fetch('audio_base_64')) }.join).to eq(data)
  end

  it 'keeps tentative text separate from committed deltas' do
    chunks = []
    protocol.process_transcription_event({ 'message_type' => 'partial_transcript', 'text' => 'Ruby' }) do |chunk|
      chunks << chunk
    end

    expect(chunks.first).to have_attributes(partial?: true, text: 'Ruby', delta: nil)
  end

  it 'rejects endpoint modes that cannot produce the requested file transcript' do
    [{ diarize: true }, { commit_strategy: 'vad' }, { include_timestamps: false },
     { filter_background_audio: true }].each do |options|
      expect { protocol.validate_streaming_transcription(options) }.to raise_error(ArgumentError)
    end
  end

  it 'reports provider errors before returning a transcript' do
    event = { 'message_type' => 'quota_exceeded', 'error' => 'Quota exceeded' }
    expect { protocol.process_transcription_event(event) { nil } }
      .to raise_error(RubyLLM::Error, 'Quota exceeded')
  end

  it 'rejects unsupported WAV encodings and channel layouts' do
    audio = instance_double(RubyLLM::Transcription::WavAudio,
                            channels: 2, encoding: 1, sample_rate: 16_000, bits_per_sample: 16)

    expect { protocol.streaming_audio_format(audio) }.to raise_error(ArgumentError, /mono 16-bit PCM WAV/)
  end
end

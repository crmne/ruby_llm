# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::Bedrock::Mantle::Voxtral do
  let(:context) do
    RubyLLM.context do |config|
      config.bedrock_region = 'us-west-2'
      config.bedrock_api_key = 'test'
      config.bedrock_secret_key = 'test'
    end
  end
  let(:model) { model_for(:bedrock, :bedrock_transcription) }
  let(:audio_path) { File.expand_path('../../../../fixtures/ruby.wav', __dir__) }
  let(:endpoint) { 'https://bedrock-mantle.us-west-2.api.aws/v1/chat/completions' }
  let(:usage) do
    { 'prompt_tokens' => 392, 'completion_tokens' => 11,
      'prompt_tokens_details' => { 'cached_tokens' => 384 } }
  end

  def event(text: nil, finish: nil, usage: nil)
    { 'model' => model, 'choices' => [{ 'delta' => { 'content' => text }.compact, 'finish_reason' => finish }],
      'usage' => usage }.compact
  end

  def stub_stream(events)
    body = "#{events.map { |data| "data: #{JSON.generate(data)}\n\n" }.join}data: [DONE]\n\n"
    stub_request(:post, endpoint).to_return(body:, headers: { 'Content-Type' => 'text/event-stream' })
  end

  def transcribe(&)
    context.transcribe(audio_path, model:, provider: :bedrock, &)
  end

  it 'signs the streaming payload and preserves usage after the final text delta' do
    request = stub_stream([
                            event(text: ''), event(text: 'Ruby is '), event(text: 'a language.', finish: 'stop'),
                            { 'choices' => [], 'usage' => usage }
                          ]).with do |req|
      payload = JSON.parse(req.body)
      expect(payload).to include('stream' => true, 'stream_options' => { 'include_usage' => true })
      expect(payload.dig('messages', 0, 'content', 0, 'input_audio', 'format')).to eq('wav')
      expect(req.headers['Authorization']).to include('/us-west-2/bedrock-mantle/aws4_request')
      expect(req.headers['X-Amz-Content-Sha256']).to eq(Digest::SHA256.hexdigest(req.body))
    end
    chunks = []

    result = transcribe { |chunk| chunks << chunk }

    expect(result).to have_attributes(text: 'Ruby is a language.', model:, words: nil, segments: nil)
    expect(chunks.filter_map(&:delta)).to eq(['Ruby is ', 'a language.'])
    expect(chunks.last).to have_attributes(done?: true, text: result.text)
    expect(chunks.count(&:done?)).to eq(1)
    expect(result.tokens).to have_attributes(input: 8, output: 11, cache_read: 384)
    expect(result.ruby_llm_usage_entries.map(&:operation)).to eq([:transcription])
    expect(result.ruby_llm_usage_entries.map(&:status)).to eq([:succeeded])
    expect(request).to have_been_requested.once
  end

  it 'keeps usage unknown when the stream does not report it' do
    stub_stream([event(text: 'Hello.', finish: 'stop')])

    result = transcribe { |chunk| expect(chunk).to be_a(RubyLLM::TranscriptionChunk) }

    expect(result.text).to eq('Hello.')
    expect(result.tokens.to_h).to be_empty
    expect(result.cost.total).to be_nil
  end

  it 'does not present a token-limited or unterminated stream as a completed transcript' do
    ['length', nil].each do |finish|
      stub_stream([event(text: 'Unfinished sentence', finish:)])
      chunks = []

      expect { transcribe { |chunk| chunks << chunk } }
        .to raise_error(RubyLLM::Error, /did not complete the transcript/)
      expect(chunks).not_to include(be_done)
    end
  end

  it 'propagates a streamed service error without retrying already delivered text' do
    context.config.max_retries = 3
    error = { 'error' => { 'type' => 'server_error', 'message' => 'Inference failed' } }
    request = stub_stream([event(text: 'Ruby'), error])
    chunks = []

    expect { transcribe { |chunk| chunks << chunk } }.to raise_error(RubyLLM::Error, /Inference failed/)
    expect(chunks.filter_map(&:delta)).to eq(['Ruby'])
    expect(chunks).not_to include(be_done)
    expect(request).to have_been_requested.once
  end

  it 'retains observed usage and records cancellation when the caller stops a streamed callback' do
    context.config.max_retries = 3
    entries = []
    allow(RubyLLM::Accounting::Usage).to receive(:instrument) { |entry, **| entries << entry }
    request = stub_stream([event(text: 'Ruby', usage:), event(text: ' is a language.', finish: 'stop')])

    expect do
      transcribe { |_chunk| raise RubyLLM::CancelledError, 'Stop transcription' }
    end.to raise_error(RubyLLM::CancelledError, 'Stop transcription')

    expect(entries.map(&:status)).to eq([:cancelled])
    expect(entries.first.tokens).to have_attributes(input: 8, output: 11, cache_read: 384)
    expect(request).to have_been_requested.once
  end
end

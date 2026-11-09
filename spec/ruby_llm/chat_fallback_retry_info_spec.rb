# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Chat do
  let(:context) do
    RubyLLM.context do |config|
      config.gemini_api_key = 'test'
      config.vertexai_project_id = 'test'
      config.vertexai_location = 'global'
      config.max_retries = 3
      config.retry_interval = 0
      config.retry_interval_randomness = 0
      config.retry_max_interval = 30
    end
  end
  let(:waits) { [] }
  let(:provider_url) { %r{\Ahttps://aiplatform\.googleapis\.com/.*gemini-2\.5-flash:} }
  let(:fallback_url) { %r{\Ahttps://generativelanguage\.googleapis\.com/.*gemini-2\.5-flash-lite:} }

  before do
    allow(RubyLLM::Providers::VertexAI::Credentials)
      .to receive(:for).and_return(instance_double(RubyLLM::Providers::VertexAI::Credentials, headers: {}))
    allow(Faraday::Retry::Middleware).to receive(:new).and_wrap_original do |constructor, *args|
      constructor.call(*args).tap { |middleware| allow(middleware).to receive(:sleep) { |delay| waits << delay } }
    end
  end

  def rate_limited(delay)
    { status: 429, headers: { 'Content-Type' => 'application/json' }, body: {
      error: { code: 429, message: 'Resource exhausted', status: 'RESOURCE_EXHAUSTED',
               details: [{ '@type': 'type.googleapis.com/google.rpc.RetryInfo', retryDelay: delay }] }
    }.to_json }
  end

  def reply(text)
    candidate = { candidates: [{ content: { role: 'model', parts: [{ text: }] }, finishReason: 'STOP' }] }

    { status: 200, headers: { 'Content-Type' => 'text/event-stream' }, body: "data: #{candidate.to_json}\n\n" }
  end

  def json_reply(text)
    candidate = { candidates: [{ content: { role: 'model', parts: [{ text: }] }, finishReason: 'STOP' }] }

    { status: 200, headers: { 'Content-Type' => 'application/json' }, body: candidate.to_json }
  end

  def chat
    context.chat(model: 'gemini-2.5-flash', provider: :vertexai, assume_model_exists: true)
           .with_fallbacks(RubyLLM::Model.default('gemini-2.5-flash-lite', 'gemini'))
  end

  {
    'a streaming request' => [->(conversation) { conversation.ask('Hi') { |_chunk| nil } }, :reply],
    'a request that does not stream' => [->(conversation) { conversation.ask('Hi') }, :json_reply]
  }.each do |path, (ask, answer)|
    describe "RetryInfo on #{path}" do
      it 'goes to the fallback at once on a long hint' do
        vertex = stub_request(:post, provider_url).to_return(rate_limited('30s'))
        gemini = stub_request(:post, fallback_url).to_return(send(answer, 'stood in'))

        expect(ask.call(chat).content).to eq('stood in')
        expect(vertex).to have_been_requested.once
        expect(gemini).to have_been_requested.once
        expect(waits).to be_empty
      end

      it 'retries on the same model on a short hint' do
        vertex = stub_request(:post, provider_url)
                 .to_return(rate_limited('1.5s')).then.to_return(send(answer, 'waited'))
        gemini = stub_request(:post, fallback_url)

        expect(ask.call(chat).content).to eq('waited')
        expect(vertex).to have_been_requested.twice
        expect(gemini).not_to have_been_requested
        expect(waits).to eq([1.5])
      end

      it 'retries at the two second bound' do
        vertex = stub_request(:post, provider_url)
                 .to_return(rate_limited('2s')).then.to_return(send(answer, 'waited'))

        expect(ask.call(chat).content).to eq('waited')
        expect(vertex).to have_been_requested.twice
        expect(waits).to eq([2.0])
      end

      it 'retries with its usual backoff on a malformed hint' do
        vertex = stub_request(:post, provider_url)
                 .to_return(rate_limited('soon')).then.to_return(send(answer, 'waited'))

        expect(ask.call(chat).content).to eq('waited')
        expect(vertex).to have_been_requested.twice
      end
    end
  end
end

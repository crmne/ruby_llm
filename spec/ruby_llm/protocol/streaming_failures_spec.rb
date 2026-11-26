# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Protocol::Streaming do
  let(:context) do
    RubyLLM.context do |config|
      config.openai_api_key = 'test'
      config.max_retries = 0
    end
  end
  let(:chat) { context.chat(model: model_for(:openai), provider: :openai) }
  let(:url) { %r{\Ahttps://api\.openai\.com/v1/} }

  def error_body(message, type: 'tokens')
    { error: { message:, type: } }.to_json
  end

  versions = { 'Faraday 1' => '1.10.0' }
  versions['Faraday 2'] = '2.0.0' unless Faraday::VERSION.start_with?('1')

  versions.each do |name, version|
    context "with #{name}" do
      before { stub_const('Faraday::VERSION', version) }

      it 'raises for a 200 with a plain JSON body instead of returning a blank answer' do
        stub_request(:post, url).to_return(status: 200, body: { id: 'x', output: [] }.to_json)

        expect { chat.ask('Hi') { |_chunk| nil } }.to raise_error(RubyLLM::Error, 'Provider returned no stream events')
        expect(chat.messages.map(&:role)).to eq([:user])
      end

      it 'raises for a 200 with an empty body' do
        stub_request(:post, url).to_return(status: 200, body: '')

        expect { chat.ask('Hi') { |_chunk| nil } }.to raise_error(RubyLLM::Error, 'Provider returned no stream events')
      end

      {
        401 => RubyLLM::UnauthorizedError, 403 => RubyLLM::ForbiddenError,
        429 => RubyLLM::RateLimitError, 503 => RubyLLM::ServiceUnavailableError
      }.each do |status, error|
        it "reports a #{status} with its own class and the provider's message" do
          stub_request(:post, url).to_return(status:, body: error_body('From the provider'))

          expect { chat.ask('Hi') { |_chunk| nil } }.to raise_error(error) { |raised|
            expect(raised.provider_message).to eq('From the provider')
          }
        end
      end

      it 'keeps the class and message of a failure body that is not JSON' do
        stub_request(:post, url).to_return(status: 400, body: 'maximum context length exceeded')

        expect { chat.ask('Hi') { |_chunk| nil } }.to raise_error(RubyLLM::ContextLengthExceededError) { |raised|
          expect(raised.provider_message).to eq('maximum context length exceeded')
        }
      end

      it 'lets an error from the caller\'s block through as it is' do
        body = %(data: {"choices":[{"delta":{"content":"hi"}}]}\n\n)
        stub_request(:post, url).to_return(status: 200, body:)

        expect { chat.ask('Hi') { |_chunk| raise NotImplementedError, 'unfinished hook' } }
          .to raise_error(NotImplementedError, 'unfinished hook')
      end

      it 'lets a Faraday network error from the caller\'s block through as it is' do
        body = %(data: {"choices":[{"delta":{"content":"hi"}}]}\n\n)
        stub_request(:post, url).to_return(status: 200, body:)

        expect { chat.ask('Hi') { |_chunk| raise Faraday::TimeoutError, 'my own request' } }
          .to raise_error(Faraday::TimeoutError, 'my own request')
      end

      it 'raises an error body sent with a 200' do
        stub_request(:post, url).to_return(status: 200, body: error_body('In the body', type: 'server_error'))

        expect { chat.ask('Hi') { |_chunk| nil } }.to raise_error(RubyLLM::ServerError, /In the body/)
      end
    end
  end

  it 'reads a streamed 2xx other than 200 as a success' do
    stub_const('Faraday::VERSION', '2.0.0')
    body = %(data: {"choices":[{"delta":{"content":"hi"},"finish_reason":"stop"}]}\n\n)
    stub_request(:post, url).to_return(status: 201, body:)

    expect(context.chat(model: model_for(:openai), provider: :openai, protocol: :chat_completions)
      .ask('Hi') { |_chunk| nil }.content).to eq('hi')
  end

  describe 'a stream that closes before its answer ends' do
    include_context 'with configured RubyLLM'

    let(:text) { { choices: [{ delta: { content: 'Hel' } }] } }

    def stub_stream(url, *events)
      body = events.map { |event| "data: #{event.is_a?(String) ? event : event.to_json}\n\n" }.join
      stub_request(:post, url).to_return(body:, headers: { 'Content-Type' => 'text/event-stream' })
    end

    def ask(provider, protocol = nil, &)
      RubyLLM.chat(model: model_for(provider), provider:, protocol:).ask('Hi', &)
    end

    {
      %i[openai chat_completions] => { choices: [{ delta: { content: 'Hel' } }] },
      %i[openai responses] => { type: 'response.output_text.delta', output_index: 0, content_index: 0, delta: 'Hel' },
      [:anthropic] => { type: 'content_block_delta', index: 0, delta: { type: 'text_delta', text: 'Hel' } },
      [:gemini] => { candidates: [{ content: { parts: [{ text: 'Hel' }] } }] },
      [:cohere] => { type: 'content-delta', index: 0, delta: { message: { content: { text: 'Hel' } } } }
    }.each do |target, event|
      it "raises on #{target.join(' ')} after delivering the text so far" do
        stub_stream(/.*/, event)
        chunks = []

        expect { ask(*target) { |chunk| chunks << chunk.content } }
          .to raise_error(RubyLLM::ConnectionError, 'Provider stream ended before completion')
        expect(chunks).to eq(['Hel'])
      end
    end

    it 'takes [DONE] or a finish reason as the end of a Chat Completions answer' do
      [['[DONE]'], [{ choices: [{ delta: {}, finish_reason: 'stop' }] }]].each do |ending|
        stub_stream(/.*/, text, *ending)

        expect(ask(:openai, :chat_completions) { |_chunk| nil }.content).to eq('Hel')
      end
    end

    it 'takes an incomplete response that names no reason as ended' do
      stub_stream(/.*/, { type: 'response.incomplete', response: { status: 'incomplete', output: [] } })

      expect { ask(:openai, :responses) { |_chunk| nil } }.not_to raise_error
    end

    it 'falls back' do
      stub_stream(/openai/, text)
      stub_stream(/generativelanguage/,
                  { candidates: [{ content: { parts: [{ text: 'Hello' }] }, finishReason: 'STOP' }] })
      chat = RubyLLM.chat(model: model_for(:openai), provider: :openai, protocol: :chat_completions)
                    .with_fallbacks(RubyLLM.models.find(model_for(:gemini), provider: :gemini))

      expect(chat.ask('Hi') { |_chunk| nil }.content).to eq('Hello')
    end
  end
end

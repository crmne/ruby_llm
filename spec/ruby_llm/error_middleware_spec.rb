# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::ErrorMiddleware do
  describe '#call' do
    it 'uses a parsed streaming error response when on_complete receives a consumed body' do
      parsed_response = Faraday::Env.from(
        status: 402,
        body: { 'error' => { 'message' => 'Your credit balance is too low' } }
      )
      completed_response = Faraday::Env.from(status: 400, body: '')
      completed_response[:streaming_error_response] = parsed_response

      app_response = instance_double(Faraday::Response)
      app = ->(_env) { app_response }
      provider = instance_double(RubyLLM::Provider)

      allow(app_response).to receive(:on_complete).and_yield(completed_response)
      allow(provider).to receive(:parse_error) do |response|
        response.body.dig('error', 'message') if response.body.is_a?(Hash)
      end

      middleware = described_class.new(app, provider: provider)

      expect do
        middleware.call(Faraday::Env.new)
      end.to raise_error(RubyLLM::PaymentRequiredError, 'Your credit balance is too low')
    end
  end

  describe '.parse_error' do
    let(:provider) { instance_double(RubyLLM::Provider, parse_error: 'provider error') }

    it 'maps 502 to ServiceUnavailableError' do
      response = Struct.new(:status, :body).new(502, '{"error":{"message":"down"}}')

      expect do
        described_class.parse_error(provider: provider, response: response)
      end.to raise_error(RubyLLM::ServiceUnavailableError)
    end

    it 'maps 503 to ServiceUnavailableError' do
      response = Struct.new(:status, :body).new(503, '{"error":{"message":"down"}}')

      expect do
        described_class.parse_error(provider: provider, response: response)
      end.to raise_error(RubyLLM::ServiceUnavailableError)
    end

    it 'maps 504 to ServiceUnavailableError' do
      response = Struct.new(:status, :body).new(504, '{"error":{"message":"timeout"}}')

      expect do
        described_class.parse_error(provider: provider, response: response)
      end.to raise_error(RubyLLM::ServiceUnavailableError)
    end

    it 'maps context-length-like 429 errors to ContextLengthExceededError' do
      response = Struct.new(:status, :body).new(429, '{"error":{"message":"Request too large for model"}}')
      provider = instance_double(RubyLLM::Provider, parse_error: 'Request too large for model')

      expect do
        described_class.parse_error(provider: provider, response: response)
      end.to raise_error(RubyLLM::ContextLengthExceededError)
    end

    it 'keeps regular 429 errors as RateLimitError' do
      response = Struct.new(:status, :body).new(429, '{"error":{"message":"Rate limit exceeded"}}')
      provider = instance_double(RubyLLM::Provider, parse_error: 'Rate limit exceeded')

      expect do
        described_class.parse_error(provider: provider, response: response)
      end.to raise_error(RubyLLM::RateLimitError)
    end

    it 'maps context-length-like 400 errors to ContextLengthExceededError' do
      msg = "This model's maximum context length is 8192 tokens."
      response = Struct.new(:status, :body).new(400, %({"error":{"message":"#{msg}"}}))
      provider = instance_double(RubyLLM::Provider, parse_error: msg)

      expect do
        described_class.parse_error(provider: provider, response: response)
      end.to raise_error(RubyLLM::ContextLengthExceededError)
    end

    it "maps Anthropic's 'prompt is too long' 400 error to ContextLengthExceededError" do
      msg = 'prompt is too long: 209025 tokens > 200000 maximum'
      response = Struct.new(:status, :body).new(400, %({"error":{"message":"#{msg}"}}))
      provider = instance_double(RubyLLM::Provider, parse_error: msg)

      expect do
        described_class.parse_error(provider: provider, response: response)
      end.to raise_error(RubyLLM::ContextLengthExceededError)
    end

    it 'keeps regular 400 errors as BadRequestError' do
      response = Struct.new(:status, :body).new(400, '{"error":{"message":"Invalid model specified"}}')
      provider = instance_double(RubyLLM::Provider, parse_error: 'Invalid model specified')

      expect do
        described_class.parse_error(provider: provider, response: response)
      end.to raise_error(RubyLLM::BadRequestError)
    end

    it 'returns the message for a successful response instead of raising' do
      response = Struct.new(:status, :body).new(200, '{}')
      provider = instance_double(RubyLLM::Provider, parse_error: nil)

      expect(described_class.parse_error(provider: provider, response: response)).to be_nil
    end

    it 'raises the base error for a status it does not map' do
      response = Struct.new(:status, :body).new(418, '{"error":{"message":"teapot"}}')
      provider = instance_double(RubyLLM::Provider, parse_error: 'teapot')

      expect do
        described_class.parse_error(provider: provider, response: response)
      end.to raise_error(RubyLLM::Error, 'teapot')
    end

    it 'maps 402 to PaymentRequiredError' do
      response = Struct.new(:status, :body).new(402, '{}')
      provider = instance_double(RubyLLM::Provider, parse_error: 'out of credit')

      expect do
        described_class.parse_error(provider: provider, response: response)
      end.to raise_error(RubyLLM::PaymentRequiredError)
    end

    it 'maps 403 to ForbiddenError' do
      response = Struct.new(:status, :body).new(403, '{}')
      provider = instance_double(RubyLLM::Provider, parse_error: 'nope')

      expect do
        described_class.parse_error(provider: provider, response: response)
      end.to raise_error(RubyLLM::ForbiddenError)
    end

    it 'maps 529 to OverloadedError' do
      response = Struct.new(:status, :body).new(529, '{}')
      provider = instance_double(RubyLLM::Provider, parse_error: 'overloaded')

      expect do
        described_class.parse_error(provider: provider, response: response)
      end.to raise_error(RubyLLM::OverloadedError)
    end

    it 'treats an empty message as neither rate limited nor over the context window' do
      response = Struct.new(:status, :body).new(429, '{}')
      provider = instance_double(RubyLLM::Provider, parse_error: nil)

      expect do
        described_class.parse_error(provider: provider, response: response)
      end.to raise_error(RubyLLM::RateLimitError)
    end

    it 'works without a provider to parse the body' do
      response = Struct.new(:status, :body).new(500, '{}')

      expect do
        described_class.parse_error(provider: nil, response: response)
      end.to raise_error(RubyLLM::ServerError)
    end
  end

  describe '#call with a hash-like response' do
    it 'reads a stored streaming error out of a hash-like response' do
      stored = Struct.new(:status, :body).new(403, '{"error":{"message":"denied"}}')
      response = { streaming_error_response: stored }
      response.define_singleton_method(:on_complete) do |&block|
        block.call(self)
        self
      end
      app = ->(_env) { response }
      provider = instance_double(RubyLLM::Provider, parse_error: 'denied')

      middleware = described_class.new(app, provider: provider)

      expect { middleware.call({}) }.to raise_error(RubyLLM::ForbiddenError, 'denied')
    end
  end
end

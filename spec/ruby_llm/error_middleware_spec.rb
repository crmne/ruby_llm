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
  end
end

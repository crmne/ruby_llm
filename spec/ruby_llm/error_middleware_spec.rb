# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::ErrorMiddleware do
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
  end
end

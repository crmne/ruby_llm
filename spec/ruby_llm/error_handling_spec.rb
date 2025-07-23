# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Error do
  it 'handles invalid API keys gracefully' do # rubocop:disable RSpec/ExampleLength
    RubyLLM.configure do |config|
      config.openai_api_key = 'invalid-key'
    end

    chat = RubyLLM.chat(model: 'gpt-4.1-nano')

    expect do
      chat.ask('Hello')
    end.to raise_error(RubyLLM::UnauthorizedError)
  end

  describe 'Provider#parse_error' do
    let(:test_provider) do
      Class.new do
        extend RubyLLM::Provider

        def self.slug
          'test_provider'
        end
      end
    end

    it 'parses error from response objects' do
      response = instance_double(Faraday::Response, body: '{"error": {"message": "API key invalid"}}')
      expect(test_provider.parse_error(response)).to eq('API key invalid')
    end

    it 'handles empty body' do
      response = instance_double(Faraday::Response, body: '')
      expect(test_provider.parse_error(response)).to be_nil
    end

    it 'handles malformed JSON' do
      response = instance_double(Faraday::Response, body: '{invalid json}')
      expect(test_provider.parse_error(response)).to eq('{invalid json}')
    end
  end

  describe 'Streaming error handling' do
    let(:test_provider) do
      Class.new do
        extend RubyLLM::Provider
        extend RubyLLM::Streaming

        def self.slug
          'test_provider'
        end

        def self.parse_streaming_error(error_data)
          data = begin
            JSON.parse(error_data)
          rescue StandardError
            {}
          end
          status = case data.dig('error', 'type')
                   when 'authentication_error' then 401
                   when 'rate_limit_error' then 429
                   else 500
                   end
          [status, data.dig('error', 'message')]
        end
      end
    end

    describe '#handle_error_chunk' do
      it 'handles error chunks with nil env' do
        chunk = "event: error\ndata: {\"error\": {\"type\": \"authentication_error\", " \
                '"message": "Invalid API key"}}'

        expect do
          test_provider.send(:handle_error_chunk, chunk, nil)
        end.to raise_error(RubyLLM::UnauthorizedError, /Invalid API key/)
      end

      it 'handles error chunks with env object' do # rubocop:disable RSpec/ExampleLength
        chunk = "event: error\ndata: {\"error\": {\"type\": \"rate_limit_error\", " \
                '"message": "Rate limit exceeded"}}'
        env = double('env', status: 429, headers: { 'content-type' => 'application/json' }) # rubocop:disable RSpec/VerifiedDoubles

        expect do
          test_provider.send(:handle_error_chunk, chunk, env)
        end.to raise_error(RubyLLM::RateLimitError, /Rate limit exceeded/)
      end
    end

    describe '#handle_failed_response' do
      it 'handles failed responses with nil env' do
        buffer = String.new
        chunk = '{"error": {"type": "authentication_error", "message": "API key expired"}}'

        expect do
          test_provider.send(:handle_failed_response, chunk, buffer, nil)
        end.to raise_error(RubyLLM::ServerError)
      end
    end

    describe '#create_error_response' do
      it 'creates a proper response object' do # rubocop:disable RSpec/ExampleLength,RSpec/MultipleExpectations
        response = test_provider.send(:create_error_response,
                                      body: { 'error' => 'test error' },
                                      status: 400,
                                      env: nil)

        expect(response).to respond_to(:body)
        expect(response).to respond_to(:status)
        expect(response.body).to eq('{"error":"test error"}')
        expect(response.status).to eq(400)
      end
    end
  end
end

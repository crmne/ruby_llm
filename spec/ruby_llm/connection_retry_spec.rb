# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Connection do
  describe 'retry middleware configuration' do
    let(:provider) do
      instance_double(
        RubyLLM::Provider,
        api_base: 'https://example.com',
        configured?: true,
        headers: {}
      )
    end

    let(:config) do
      instance_double(
        RubyLLM::Configuration,
        request_timeout: 300,
        max_retries: 3,
        retry_interval: 0.1,
        retry_max_interval: 30,
        retry_interval_randomness: 0.5,
        retry_backoff_factor: 2,
        http_proxy: nil,
        log_regexp_timeout: 1.0,
        faraday_adapter: :net_http
      )
    end

    it 'retries POST requests for transient failures' do
      connection = described_class.new(provider, config).connection
      retry_handler = connection.builder.handlers.find { |handler| handler.klass == Faraday::Retry::Middleware }
      retry_options = retry_handler.instance_variable_get(:@args).first

      expect(retry_options[:retry_if].call({ method: :post }, nil)).to be(true)
    end

    it 'does not retry a POST once its stream has delivered chunks' do
      connection = described_class.new(provider, config).connection
      retry_handler = connection.builder.handlers.find { |handler| handler.klass == Faraday::Retry::Middleware }
      retry_options = retry_handler.instance_variable_get(:@args).first

      request = Faraday::RequestOptions.from(
        context: { RubyLLM::Streaming::PROGRESS_KEY => { started: true } }
      )

      expect(retry_options[:retry_if].call({ method: :post, request: request }, nil)).to be(false)
    end

    it 'does not retry a POST the caller marked non-idempotent' do
      connection = described_class.new(provider, config).connection
      retry_handler = connection.builder.handlers.find { |handler| handler.klass == Faraday::Retry::Middleware }
      retry_options = retry_handler.instance_variable_get(:@args).first

      request = Faraday::RequestOptions.from(context: { RubyLLM::Connection::IDEMPOTENT_KEY => false })

      expect(retry_options[:retry_if].call({ method: :post, request: request }, nil)).to be(false)
    end

    it 'caps retry delays at retry_max_interval' do
      connection = described_class.new(provider, config).connection
      retry_handler = connection.builder.handlers.find { |handler| handler.klass == Faraday::Retry::Middleware }
      retry_options = retry_handler.instance_variable_get(:@args).first

      expect(retry_options[:max_interval]).to eq(30)
    end
  end

  describe 'rate limit retry timing' do
    let(:config) do
      RubyLLM::Configuration.new.tap do |c|
        c.openai_api_key = 'test-key'
        c.max_retries = 1
        c.retry_interval = 0
        c.retry_interval_randomness = 0
      end
    end

    let(:provider) { RubyLLM::Providers::OpenAI.new(config) }

    it 'retries after the provider supplies a delay' do
      stub = stub_request(:post, 'https://api.openai.com/v1/chat/completions')
             .to_return(
               { status: 429,
                 headers: { 'x-ratelimit-reset-requests' => '0ms' },
                 body: '{"error":{"message":"Rate limit reached"}}' },
               { status: 200, headers: { 'Content-Type' => 'application/json' }, body: '{}' }
             )

      response = provider.connection.post('chat/completions', {})

      expect(response.status).to eq(200)
      expect(stub).to have_been_requested.twice
    end

    it 'gives up immediately when the provider asks to wait longer than retry_max_interval' do
      config.retry_max_interval = 5
      stub = stub_request(:post, 'https://api.openai.com/v1/chat/completions')
             .to_return(
               status: 429,
               headers: { 'x-ratelimit-reset-requests' => '6m0s' },
               body: '{"error":{"message":"Rate limit reached"}}'
             )

      expect { provider.connection.post('chat/completions', {}) }.to raise_error(RubyLLM::RateLimitError)
      expect(stub).to have_been_requested.once
    end

    it 'retries a chat completion that fails with a server error' do
      stub = stub_request(:post, 'https://api.openai.com/v1/chat/completions')
             .to_return(
               { status: 500, body: '{"error":{"message":"Internal server error"}}' },
               { status: 200, headers: { 'Content-Type' => 'application/json' }, body: '{}' }
             )

      response = provider.connection.post('chat/completions', {})

      expect(response.status).to eq(200)
      expect(stub).to have_been_requested.twice
    end
  end

  describe 'job-creating requests' do
    let(:config) do
      RubyLLM::Configuration.new.tap do |c|
        c.anthropic_api_key = 'test-key'
        c.max_retries = 3
        c.retry_interval = 0
        c.retry_interval_randomness = 0
      end
    end

    let(:provider) { RubyLLM::Providers::Anthropic.new(config) }
    let(:requests) { [{ custom_id: 'ruby_llm_0', payload: { model: 'claude-haiku-4-5', messages: [] } }] }
    let(:created_batch) do
      { status: 200,
        headers: { 'Content-Type' => 'application/json' },
        body: '{"id":"msgbatch_01","processing_status":"in_progress"}' }
    end

    it 'submits a batch once when the first attempt fails with a server error' do
      stub = stub_request(:post, 'https://api.anthropic.com/v1/messages/batches')
             .to_return({ status: 500, body: '{"error":{"message":"Internal server error"}}' }, created_batch)

      expect { provider.create_batch(requests) }.to raise_error(RubyLLM::ServerError)
      expect(stub).to have_been_requested.once
    end

    it 'submits a batch once when the first attempt times out' do
      stub = stub_request(:post, 'https://api.anthropic.com/v1/messages/batches')
             .to_timeout.then.to_return(created_batch)

      expect { provider.create_batch(requests) }.to raise_error(Faraday::ConnectionFailed)
      expect(stub).to have_been_requested.once
    end
  end
end

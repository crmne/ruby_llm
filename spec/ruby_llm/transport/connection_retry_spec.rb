# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Transport::Connection do
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
        logger: nil,
        request_timeout: 300,
        max_retries: 3,
        retry_interval: 0.1,
        retry_max_interval: 30,
        retry_interval_randomness: 0.5,
        retry_backoff_factor: 2,
        http_proxy: nil,
        ssl: nil,
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
        context: { RubyLLM::Transport::Connection::STREAM_PROGRESS_KEY => { started: true } }
      )

      expect(retry_options[:retry_if].call({ method: :post, request: request }, nil)).to be(false)
    end

    it 'does not retry a POST the caller marked non-idempotent' do
      connection = described_class.new(provider, config).connection
      retry_handler = connection.builder.handlers.find { |handler| handler.klass == Faraday::Retry::Middleware }
      retry_options = retry_handler.instance_variable_get(:@args).first

      request = Faraday::RequestOptions.from(context: { RubyLLM::Transport::Connection::IDEMPOTENT_KEY => false })

      expect(retry_options[:retry_if].call({ method: :post, request: request }, nil)).to be(false)
    end

    it 'retries an error without a response while a fallback is ready' do
      connection = described_class.new(provider, config).connection
      retry_handler = connection.builder.handlers.find { |handler| handler.klass == Faraday::Retry::Middleware }
      retry_if = retry_handler.instance_variable_get(:@args).first[:retry_if]

      retried = described_class.with_fallback_ready(->(_error) { true }) do
        retry_if.call({ method: :post }, RubyLLM::RateLimitError.new('Slow down'))
      end

      expect(retried).to be(true)
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
    let(:retry_delays) { [] }

    before do
      allow(Faraday::Retry::Middleware).to receive(:new).and_wrap_original do |constructor, *args|
        constructor.call(*args).tap do |middleware|
          allow(middleware).to receive(:sleep) { |delay| retry_delays << delay }
        end
      end
    end

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

    describe 'while a fallback is ready' do
      def rate_limited(retry_after)
        stub_request(:post, 'https://api.openai.com/v1/chat/completions')
          .to_return(
            { status: 429, headers: { 'Retry-After' => retry_after },
              body: '{"error":{"message":"Rate limit reached"}}' },
            { status: 200, headers: { 'Content-Type' => 'application/json' }, body: '{}' }
          )
      end

      def post(ready: ->(_error) { true })
        described_class.with_fallback_ready(ready) { provider.connection.post('chat/completions', {}) }
      end

      it 'waits out a retry hint of up to two seconds' do
        stub = rate_limited('2')

        expect(post.status).to eq(200)
        expect(retry_delays).to eq([2.0])
        expect(stub).to have_been_requested.twice
      end

      it 'leaves a longer retry hint to the fallback' do
        stub = rate_limited('2.5')

        expect { post }.to raise_error(RubyLLM::RateLimitError)
        expect(stub).to have_been_requested.once
      end

      it 'reads a retry hint given as an HTTP date' do
        stub = rate_limited((Time.now + 20).httpdate)

        expect { post }.to raise_error(RubyLLM::RateLimitError)
        expect(stub).to have_been_requested.once
      end

      it 'retries on a retry hint it cannot read' do
        stub = rate_limited('soon')

        expect(post.status).to eq(200)
        expect(stub).to have_been_requested.twice
      end

      it 'waits as before when the fallback would not take the error' do
        stub = rate_limited('20')

        expect(post(ready: ->(error) { !error.is_a?(RubyLLM::RateLimitError) }).status).to eq(200)
        expect(retry_delays).to eq([20.0])
        expect(stub).to have_been_requested.twice
      end

      it 'leaves a timeout to the fallback' do
        stub = stub_request(:post, 'https://api.openai.com/v1/chat/completions').to_raise(Net::ReadTimeout.new)

        expect { post }.to raise_error(RubyLLM::ConnectionError)
        expect(stub).to have_been_requested.once
      end
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

    it 'sends every upload part again when a multipart request is retried' do
      bodies = []
      stub_request(:post, 'https://api.openai.com/v1/images/edits').to_return do |request|
        bodies << request.body
        if bodies.one?
          { status: 500, body: '{"error":{"message":"Internal server error"}}' }
        else
          { status: 200, headers: { 'Content-Type' => 'application/json' }, body: '{}' }
        end
      end
      parts = %w[first second].map { |bytes| Faraday::UploadIO.new(StringIO.new(bytes), 'image/png', "#{bytes}.png") }

      provider.connection.post('images/edits', { image: parts })

      expect(bodies.size).to eq(2)
      expect(bodies.last).to eq(bodies.first).and include('first', 'second')
    end

    it 'retries a chat completion whose TLS connection fails' do
      stub = stub_request(:post, 'https://api.openai.com/v1/chat/completions')
             .to_raise(OpenSSL::SSL::SSLError.new('SSL_connect returned=1 errno=0 state=error: unexpected eof'))
             .then.to_return(status: 200, headers: { 'Content-Type' => 'application/json' }, body: '{}')

      response = provider.connection.post('chat/completions', {})

      expect(response.status).to eq(200)
      expect(stub).to have_been_requested.twice
    end

    {
      'a refused connection' => [Errno::ECONNREFUSED.new, Faraday::ConnectionFailed, false],
      'a timeout' => [Net::ReadTimeout.new, Faraday::TimeoutError, true],
      'a connection that timed out opening' => [Net::OpenTimeout.new, Faraday::ConnectionFailed, true],
      'a TLS failure' => [OpenSSL::SSL::SSLError.new('certificate verify failed'), Faraday::SSLError, false]
    }.each do |failure, (raised, wrapped, timeout)|
      it "raises a RubyLLM::ConnectionError after retrying #{failure}" do
        stub = stub_request(:post, 'https://api.openai.com/v1/chat/completions').to_raise(raised)

        expect { provider.connection.post('chat/completions', {}) }.to raise_error(RubyLLM::ConnectionError) { |error|
          expect(error.cause).to be_a(wrapped)
          expect(error.provider).to eq('openai')
          expect(error.timeout?).to be(timeout)
        }
        expect(stub).to have_been_requested.twice
      end
    end

    [429, 500, 503, 529].each do |status|
      it "honors millisecond retry delays for HTTP #{status}" do
        stub = stub_request(:post, 'https://api.openai.com/v1/chat/completions')
               .to_return(
                 { status:, headers: { 'retry-after-ms' => '1500' },
                   body: '{"error":{"message":"Try again later"}}' },
                 { status: 200, headers: { 'Content-Type' => 'application/json' }, body: '{}' }
               )
        expect(provider.connection.post('chat/completions', {}).status).to eq(200)
        expect(retry_delays).to eq([1.5])
        expect(stub).to have_been_requested.twice
      end
    end

    it 'does not retry before an excessive millisecond delay has elapsed' do
      config.retry_max_interval = 5
      stub = stub_request(:post, 'https://api.openai.com/v1/chat/completions')
             .to_return(status: 529, headers: { 'retry-after-ms' => '6000' },
                        body: '{"error":{"message":"Overloaded"}}')

      expect { provider.connection.post('chat/completions', {}) }.to raise_error(RubyLLM::OverloadedError)
      expect(stub).to have_been_requested.once
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
    let(:requests) { [{ custom_id: 'ruby_llm_0', payload: { model: model_for(:anthropic), messages: [] } }] }
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

      expect { provider.create_batch(requests) }.to raise_error(RubyLLM::ConnectionError)
      expect(stub).to have_been_requested.once
    end

    it 'submits a batch once when the first attempt fails with a TLS error' do
      stub = stub_request(:post, 'https://api.anthropic.com/v1/messages/batches')
             .to_raise(OpenSSL::SSL::SSLError.new('SSL_read: unexpected eof while reading'))
             .then.to_return(created_batch)

      expect { provider.create_batch(requests) }.to raise_error(RubyLLM::ConnectionError)
      expect(stub).to have_been_requested.once
    end
  end
end

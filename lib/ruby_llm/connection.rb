# frozen_string_literal: true

require 'faraday'
require 'faraday/multipart'
require 'faraday/retry'
require 'ruby_llm/error_middleware'
require 'ruby_llm/usage_middleware'
require 'timeout'

module RubyLLM
  class Connection # :nodoc:
    include Inspectable

    attr_reader :provider, :connection, :config

    def self.basic(&)
      Faraday.new do |f|
        f.options.timeout = RubyLLM.config.request_timeout
        f.proxy = RubyLLM.config.http_proxy if RubyLLM.config.http_proxy
        f.response :logger,
                   RubyLLM.logger,
                   bodies: false,
                   errors: true,
                   headers: false,
                   log_level: :debug
        f.response :raise_error
        yield f if block_given?
      end
    end

    def initialize(provider, config, api_base: nil)
      @provider = provider
      @config = config

      @connection = Faraday.new(api_base || provider.api_base) do |faraday|
        setup_timeout(faraday)
        setup_logging(faraday)
        setup_retry(faraday)
        setup_middleware(faraday)
        setup_http_proxy(faraday)
      end
    end

    def post(url, payload, usage: nil, &)
      instrument_request(:post, url) do
        @connection.post url, payload do |req|
          req.headers.merge! @provider.headers
          set_usage_tracker(req, usage) if usage
          yield req if block_given?
        end
      end
    end

    def get(url, &)
      instrument_request(:get, url) do
        @connection.get url do |req|
          req.headers.merge! @provider.headers
          yield req if block_given?
        end
      end
    end

    def patch(url, payload, &)
      instrument_request(:patch, url) do
        @connection.patch url, payload do |req|
          req.headers.merge! @provider.headers
          yield req if block_given?
        end
      end
    end

    def delete(url, &)
      instrument_request(:delete, url) do
        @connection.delete url do |req|
          req.headers.merge! @provider.headers
          yield req if block_given?
        end
      end
    end

    private

    def instrument_request(method, url)
      payload = {
        provider: @provider.slug,
        method: method,
        url: url
      }

      RubyLLM.instrument('request.ruby_llm', payload, config: @config) do |event|
        response = yield
        event[:status] = response.status if response.respond_to?(:status)
        response
      end
    end

    def setup_timeout(faraday)
      faraday.options.timeout = @config.request_timeout
    end

    def setup_logging(faraday)
      faraday.response :logger,
                       RubyLLM.logger,
                       bodies: RubyLLM.logger.debug?,
                       errors: true,
                       headers: false,
                       log_level: :debug do |logger|
        logger.filter(logging_regexp('[A-Za-z0-9+/=]{100,}'), '[BASE64 DATA]')
        logger.filter(logging_regexp('[-\\d.e,\\s]{100,}'), '[EMBEDDINGS ARRAY]')
      end
    end

    def logging_regexp(pattern)
      return Regexp.new(pattern) if @config.log_regexp_timeout.nil? || !Regexp.respond_to?(:timeout)

      Regexp.new(pattern, timeout: @config.log_regexp_timeout)
    end

    def setup_retry(faraday)
      faraday.request :retry, {
        max: @config.max_retries,
        interval: @config.retry_interval,
        max_interval: @config.retry_max_interval,
        interval_randomness: @config.retry_interval_randomness,
        backoff_factor: @config.retry_backoff_factor,
        methods: Faraday::Retry::Middleware::IDEMPOTENT_METHODS,
        retry_if: ->(env, _exception) { env[:method] == :post && !stream_delivered?(env) },
        exceptions: retry_exceptions
      }
      faraday.use :llm_usage
    end

    def stream_delivered?(env)
      env[:request]&.context&.dig(Streaming::PROGRESS_KEY, :started)
    end

    def setup_middleware(faraday)
      faraday.request :multipart
      faraday.request :json
      faraday.response :json
      faraday.adapter(@config.faraday_adapter)
      faraday.use :llm_errors, provider: @provider
    end

    def setup_http_proxy(faraday)
      return unless @config.http_proxy

      faraday.proxy = @config.http_proxy
    end

    def retry_exceptions
      [
        Errno::ETIMEDOUT,
        Timeout::Error,
        Faraday::TimeoutError,
        Faraday::ConnectionFailed,
        Faraday::RetriableResponse,
        RubyLLM::RateLimitError,
        RubyLLM::ServerError,
        RubyLLM::ServiceUnavailableError,
        RubyLLM::OverloadedError
      ]
    end

    def set_usage_tracker(request, tracker)
      context = request.options.context ||= {}
      context[UsageMiddleware::CONTEXT_KEY] = tracker
    end

    def inspect_attributes # :nodoc:
      { provider: @provider.slug }
    end
  end
end

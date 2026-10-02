# frozen_string_literal: true

require 'faraday'
require 'faraday/multipart'
require 'faraday/retry'
require 'ruby_llm/transport/error_middleware'
require 'ruby_llm/transport/usage_middleware'
require 'timeout'

module RubyLLM
  module Transport # :nodoc:
    class Connection # :nodoc:
      include Support::Inspectable

      IDEMPOTENT_KEY = :ruby_llm_idempotent
      STREAM_PROGRESS_KEY = :ruby_llm_stream_progress

      # The key a shared Faraday connection is cached under: the provider,
      # whether it streams, and everything ::build reads.
      Settings = Struct.new(
        :provider, :stream, :api_base, :adapter, :timeout, :proxy, :logger, :log_bodies, :log_regexp_timeout,
        :max_retries, :retry_interval, :retry_max_interval, :retry_interval_randomness, :retry_backoff_factor,
        keyword_init: true
      )

      CACHE = Support::ProcessCache.new

      attr_reader :provider, :config

      def self.basic(config = RubyLLM.config, &)
        Faraday.new do |f|
          f.options.timeout = config.request_timeout
          f.proxy = config.http_proxy if config.http_proxy
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

      def self.cache
        CACHE
      end

      # The result is shared across threads and contexts, so the middleware
      # stack is built now rather than lazily, without a lock, on the first
      # request, and the defaults every request copies are frozen.
      def self.build(settings)
        connection = Faraday.new(settings.api_base) do |faraday|
          setup_timeout(faraday, settings)
          setup_logging(faraday, settings)
          setup_retry(faraday, settings)
          setup_middleware(faraday, settings)
          setup_http_proxy(faraday, settings)
        end
        [connection.headers, connection.params, connection.options].each(&:freeze)
        connection.app
        connection
      end

      def initialize(provider, config, api_base: nil, headers: {})
        @provider = provider
        @config = config
        @headers = headers
        @settings = settings_for(api_base || provider.api_base)
        @stream_settings = @settings.dup.tap { |settings| settings.stream = true }.freeze
        connection
      end

      # The Faraday connection shared by every request with these settings in
      # this process. Looked up per request, so an object that outlives a fork
      # never reaches the parent's sockets. Streaming requests get their own:
      # some adapters, such as httpx, only stream if their first request did.
      def connection(stream: false)
        settings = stream ? @stream_settings : @settings
        CACHE.fetch(settings) { self.class.build(settings) }
      end

      def post(url, payload, usage: nil, idempotent: true, stream: false, &)
        instrument_request(:post, url) do
          response = connection(stream:).post url, payload do |req|
            prepare(req)
            set_usage_tracker(req, usage) if usage
            mark_non_idempotent(req) unless idempotent
            yield req if block_given?
          end
          release_request(response)
        end
      end

      def get(url, &)
        instrument_request(:get, url) do
          connection.get url do |req|
            prepare(req)
            yield req if block_given?
          end
        end
      end

      def patch(url, payload, &)
        instrument_request(:patch, url) do
          response = connection.patch url, payload do |req|
            prepare(req)
            yield req if block_given?
          end
          release_request(response)
        end
      end

      def delete(url, &)
        instrument_request(:delete, url) do
          connection.delete url do |req|
            prepare(req)
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

      # The response outlives the call as Message#raw and other results. A chat
      # request body is the whole serialized conversation, and a streaming
      # callback closes over the payload it was built from.
      def release_request(response)
        response.env.request_body = nil
        response.env.request.on_data = nil
        response
      end

      def settings_for(api_base)
        Settings.new(
          provider: @provider.class,
          stream: false,
          api_base: api_base,
          adapter: @config.faraday_adapter,
          timeout: @config.request_timeout,
          proxy: @config.http_proxy,
          logger: RubyLLM.logger,
          log_bodies: RubyLLM.logger.debug?,
          log_regexp_timeout: @config.log_regexp_timeout,
          max_retries: @config.max_retries,
          retry_interval: @config.retry_interval,
          retry_max_interval: @config.retry_max_interval,
          retry_interval_randomness: @config.retry_interval_randomness,
          retry_backoff_factor: @config.retry_backoff_factor
        ).freeze
      end

      # Credentials and the provider that parses errors travel with each
      # request, because the Faraday connection is shared across contexts.
      def prepare(request)
        request.headers.merge!(@headers).merge!(@provider.headers)
        (request.options.context ||= {})[ErrorMiddleware::PROVIDER_KEY] = @provider
      end

      def self.setup_timeout(faraday, settings)
        faraday.options.timeout = settings.timeout
      end

      def self.setup_logging(faraday, settings)
        faraday.response :logger,
                         settings.logger,
                         bodies: settings.log_bodies,
                         errors: true,
                         headers: false,
                         log_level: :debug do |logger|
          logger.filter(logging_regexp('[A-Za-z0-9+/=]{100,}', settings), '[BASE64 DATA]')
          logger.filter(logging_regexp('[-\\d.e,\\s]{100,}', settings), '[EMBEDDINGS ARRAY]')
        end
      end

      def self.logging_regexp(pattern, settings)
        return Regexp.new(pattern) if settings.log_regexp_timeout.nil?

        Regexp.new(pattern, timeout: settings.log_regexp_timeout)
      end

      def self.setup_retry(faraday, settings)
        faraday.request :retry, {
          max: settings.max_retries,
          interval: settings.retry_interval,
          max_interval: settings.retry_max_interval,
          interval_randomness: settings.retry_interval_randomness,
          backoff_factor: settings.retry_backoff_factor,
          methods: Faraday::Retry::Middleware::IDEMPOTENT_METHODS,
          retry_if: lambda { |env, _exception|
            env[:method] == :post && idempotent?(env) && !stream_delivered?(env)
          },
          exceptions: retry_exceptions
        }
        faraday.use :llm_usage
      end

      def self.stream_delivered?(env)
        env[:request]&.context&.dig(STREAM_PROGRESS_KEY, :started)
      end

      def self.idempotent?(env)
        env[:request]&.context&.dig(IDEMPOTENT_KEY) != false
      end

      def self.setup_middleware(faraday, settings)
        faraday.request :multipart
        faraday.request :json
        faraday.use JsonResponse
        faraday.adapter(settings.adapter)
        faraday.use :llm_errors
      end

      def self.setup_http_proxy(faraday, settings)
        return unless settings.proxy

        faraday.proxy = settings.proxy
      end

      def self.retry_exceptions
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

      private_class_method :setup_timeout, :setup_logging, :logging_regexp, :setup_retry, :stream_delivered?,
                           :idempotent?, :setup_middleware, :setup_http_proxy, :retry_exceptions

      def set_usage_tracker(request, tracker)
        context = request.options.context ||= {}
        context[UsageMiddleware::CONTEXT_KEY] = tracker
      end

      # A request that creates server-side state cannot be replayed: a retry
      # after a lost response submits the job a second time.
      def mark_non_idempotent(request)
        context = request.options.context ||= {}
        context[IDEMPOTENT_KEY] = false
      end

      def inspect_attributes # :nodoc:
        { provider: @provider.slug }
      end
    end
  end
end

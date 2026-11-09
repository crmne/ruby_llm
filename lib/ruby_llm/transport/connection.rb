# frozen_string_literal: true

require 'faraday'
require 'faraday/multipart'
require 'faraday/retry'
require 'ruby_llm/transport/error_middleware'
require 'ruby_llm/transport/signing_middleware'
require 'ruby_llm/transport/usage_middleware'
require 'time'
require 'timeout'

module RubyLLM
  module Transport # :nodoc:
    class Connection # :nodoc:
      include Support::Inspectable

      IDEMPOTENT_KEY = :ruby_llm_idempotent
      STREAM_PROGRESS_KEY = :ruby_llm_stream_progress
      FALLBACK_KEY = :ruby_llm_fallback_ready

      # The longest wait, in seconds, a rate-limited or overloaded model's
      # retry hint may ask for before a fallback takes the request instead.
      # Providers often ask for a second or two, which costs less than
      # moving to another model; waits of ten seconds or more are left to
      # a fallback when one is configured.
      FALLBACK_WAIT = 2

      # The key a shared Faraday connection is cached under: the provider,
      # whether it streams, and everything ::build reads.
      Settings = Struct.new(
        :provider, :stream, :api_base, :adapter, :timeout, :connect_timeout, :idle_timeout, :proxy, :ssl, :logger,
        :log_bodies, :log_regexp_timeout, :max_retries, :retry_interval, :retry_max_interval,
        :retry_interval_randomness, :retry_backoff_factor,
        keyword_init: true
      )

      CACHE = Support::ProcessCache.new
      REDIRECTS = [301, 302, 303, 307, 308].freeze
      REDIRECT_LIMIT = 5

      attr_reader :provider, :config

      def self.basic(config = RubyLLM.config, &)
        Faraday.new do |f|
          f.use ReleaseRequest
          f.options.timeout = config.request_timeout
          f.options.open_timeout = config.connect_timeout
          f.proxy = config.http_proxy if config.http_proxy
          f.ssl.update(ssl_snapshot(config.ssl)) if config.ssl
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

      # Fetches the body at +url+ with no credentials, so a redirect to
      # another host carries none.
      def self.download(url, config = RubyLLM.config)
        connection = basic(config)
        uri = URI(url.to_s)
        response = connection.get(uri)
        REDIRECT_LIMIT.times do
          break unless REDIRECTS.include?(response.status) && response.headers['location']

          uri = redirect_target(uri, response.headers['location'])
          response = connection.get(uri)
        end
        return response.body if response.success?

        raise Error.new("Download from #{uri.host} failed with status #{response.status}", response:)
      end

      def self.redirect_target(from, location)
        target = URI.join(from, location)
        return target if target.scheme == 'https' || (target.scheme == 'http' && from.scheme == 'http')

        raise Error, "Download from #{from.host} redirected to an unsafe #{target.scheme} URL"
      rescue URI::InvalidURIError
        raise Error, "Download from #{from.host} redirected to an invalid URL"
      end
      private_class_method :redirect_target

      def self.cache
        CACHE
      end

      # Runs the block with a fallback model ready to take over its
      # requests: +ready+ answers whether an error moves on to it. Until the
      # block returns, a timeout or a failed connection is not retried on
      # the same model, nor an error whose retry hint asks for a wait
      # longer than FALLBACK_WAIT, when +ready+ accepts the error.
      def self.with_fallback_ready(ready)
        previous = Fiber[FALLBACK_KEY]
        Fiber[FALLBACK_KEY] = ready
        yield
      ensure
        Fiber[FALLBACK_KEY] = previous
      end

      # A frozen copy of +ssl+, so a value changed in place afterwards
      # reaches neither a cache key nor a connection already built.
      def self.ssl_snapshot(ssl)
        ssl.to_h.transform_values { |value| value.is_a?(String) ? value.dup.freeze : value }.freeze
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
          setup_ssl(faraday, settings)
        end
        [connection.headers, connection.params, connection.options].each(&:freeze)
        connection.app
        connection
      end

      def initialize(provider, config, api_base: nil, headers: {}, signer: nil)
        @provider = provider
        @config = config
        @headers = headers
        @signer = signer
        @api_base = api_base
        connection
      end

      # The Faraday connection shared by every request with these settings in
      # this process. Looked up per request, so an object that outlives a fork
      # never reaches the parent's sockets, and a request goes to the endpoint
      # configured for the credentials it carries. Streaming requests get
      # their own: some adapters, such as httpx, only stream if their first
      # request did.
      def connection(stream: false)
        settings = settings_for(stream)
        CACHE.fetch(settings) { self.class.build(settings) }
      end

      def post(url, payload, usage: nil, idempotent: true, stream: false, &)
        instrument_request(:post, url) do
          connection(stream:).post url, payload do |req|
            prepare(req)
            set_usage_tracker(req, usage) if usage
            mark_non_idempotent(req) unless idempotent
            yield req if block_given?
          end
        end
      end

      def get(url, raw: false, &)
        instrument_request(:get, url) do
          connection.get url do |req|
            prepare(req)
            keep_raw_body(req) if raw
            yield req if block_given?
          end
        end
      end

      def patch(url, payload, &)
        instrument_request(:patch, url) do
          connection.patch url, payload do |req|
            prepare(req)
            yield req if block_given?
          end
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
          response = ReleaseRequest.release(yield)
          event[:status] = response.status if response.respond_to?(:status)
          response
        rescue RubyLLM::Error => e
          ReleaseRequest.release(e.response)
          raise
        end
      end

      def settings_for(stream)
        logger = @config.logger || RubyLLM.logger
        Settings.new(
          provider: @provider.class,
          stream: stream,
          api_base: @api_base || @provider.api_base,
          adapter: @config.faraday_adapter,
          timeout: @config.request_timeout,
          connect_timeout: @config.connect_timeout,
          idle_timeout: (@config.stream_idle_timeout if stream),
          proxy: @config.http_proxy,
          ssl: (self.class.ssl_snapshot(@config.ssl) if @config.ssl),
          logger: logger,
          log_bodies: logger.debug?,
          log_regexp_timeout: @config.log_regexp_timeout,
          max_retries: @config.max_retries,
          retry_interval: @config.retry_interval,
          retry_max_interval: @config.retry_max_interval,
          retry_interval_randomness: @config.retry_interval_randomness,
          retry_backoff_factor: @config.retry_backoff_factor
        ).freeze
      end

      # Credentials, the signer, and the provider that parses errors travel
      # with each request, because the Faraday connection is shared across
      # contexts.
      def prepare(request)
        request.headers.merge!(@headers).merge!(@provider.headers)
        context = request.options.context ||= {}
        context[ErrorMiddleware::PROVIDER_KEY] = @provider
        context[SigningMiddleware::CONTEXT_KEY] = @signer if @signer
      end

      # Adapters time each read of a response with +read_timeout+, so on a
      # streaming connection it is the longest wait for the next bytes.
      def self.setup_timeout(faraday, settings)
        faraday.options.timeout = settings.timeout
        faraday.options.open_timeout = settings.connect_timeout
        faraday.options.read_timeout = settings.idle_timeout if settings.idle_timeout
      end

      def self.setup_logging(faraday, settings)
        faraday.response :logger,
                         settings.logger,
                         bodies: settings.log_bodies,
                         errors: true,
                         headers: false,
                         log_level: :debug,
                         formatter: LogFormatter do |logger|
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
          retry_if: lambda { |env, exception|
            Support::Cancellation.check
            env[:method] == :post && idempotent?(env) && !stream_delivered?(env) &&
              !fall_back_instead?(env, exception)
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

      # Whether a fallback set up by ::with_fallback_ready takes this
      # failure instead of a retry on the same model.
      def self.fall_back_instead?(env, exception)
        ready = Fiber[FALLBACK_KEY]
        return false unless ready && exception

        error = exception.is_a?(RubyLLM::Error) ? exception : RubyLLM::ConnectionError.new(exception.message)
        return false unless ready.call(error)

        error.is_a?(RubyLLM::ConnectionError) || retry_wait(env, error) > FALLBACK_WAIT
      end

      # The wait in seconds the response's retry hints ask for, read as the
      # retry middleware reads them, or 0 without one.
      def self.retry_wait(env, error)
        headers = env[:response_headers] || error.response&.headers || {}
        %w[Retry-After RateLimit-Reset].filter_map { |name| header_seconds(headers[name]) }.max || 0
      end

      def self.header_seconds(value)
        text = value.to_s.strip
        Float(text, exception: false) || (Time.httpdate(text) - Time.now)
      rescue ArgumentError
        nil
      end

      def self.setup_middleware(faraday, settings)
        faraday.request :multipart
        faraday.request :json
        faraday.use :llm_signing
        faraday.use JsonResponse
        faraday.adapter(settings.adapter, **adapter_options(settings))
        faraday.use :llm_errors
      end

      # async-http-faraday reads its timeout for each read from its own
      # options rather than the request's.
      def self.adapter_options(settings)
        return {} unless settings.adapter == :async_http && settings.idle_timeout

        { read_timeout: settings.idle_timeout }
      end

      def self.setup_http_proxy(faraday, settings)
        return unless settings.proxy

        faraday.proxy = settings.proxy
      end

      def self.setup_ssl(faraday, settings)
        return unless settings.ssl

        faraday.ssl.update(settings.ssl)
      end

      def self.retry_exceptions
        [
          Errno::ETIMEDOUT,
          Timeout::Error,
          Faraday::TimeoutError,
          Faraday::ConnectionFailed,
          Faraday::SSLError,
          Faraday::RetriableResponse,
          RubyLLM::ConnectionError,
          RubyLLM::RateLimitError,
          RubyLLM::ServerError,
          RubyLLM::ServiceUnavailableError,
          RubyLLM::OverloadedError
        ]
      end

      private_class_method :setup_timeout, :setup_logging, :logging_regexp, :setup_retry, :stream_delivered?,
                           :idempotent?, :fall_back_instead?, :retry_wait, :header_seconds, :setup_middleware,
                           :adapter_options, :setup_http_proxy, :setup_ssl, :retry_exceptions

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

      def keep_raw_body(request)
        context = request.options.context ||= {}
        context[JsonResponse::RAW_KEY] = true
      end

      def inspect_attributes # :nodoc:
        { provider: @provider.slug }
      end
    end
  end
end

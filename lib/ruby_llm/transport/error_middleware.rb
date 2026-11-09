# frozen_string_literal: true

require 'faraday'
require 'ruby_llm/error'

module RubyLLM
  module Transport # :nodoc:
    class ErrorMiddleware < Faraday::Middleware # :nodoc: all
      PROVIDER_KEY = :ruby_llm_provider
      STREAM_RESET_KEY = :ruby_llm_stream_reset
      STREAM_FAILURE_KEY = :ruby_llm_stream_failure
      NETWORK_FAILURES = [Faraday::ConnectionFailed, Faraday::TimeoutError, Faraday::SSLError].freeze

      def initialize(app, options = {})
        super(app)
        @provider = options[:provider]
      end

      # Sits directly above the adapter, inside the retry middleware, so this
      # runs once per attempt: streaming state stored on the env by a previous
      # attempt must not leak into the next one, and a body the previous
      # attempt read to its end is sent again from its start.
      def call(env)
        context = env[:request]&.context
        provider = context&.[](PROVIDER_KEY) || @provider
        attempt(env, context, provider)
      rescue *NETWORK_FAILURES => e
        raise if context&.dig(Connection::STREAM_PROGRESS_KEY, :callback_error).equal?(e)

        raise ConnectionError.new(e.message, provider: (provider.slug if provider.respond_to?(:slug)))
      end

      private

      def attempt(env, context, provider)
        env[:streaming_error_response] = nil
        env[:streaming_state] = nil
        env[:body].rewind if env[:body].respond_to?(:rewind)
        context&.[](STREAM_RESET_KEY)&.call
        @app.call(env).on_complete do |response|
          context&.[](STREAM_FAILURE_KEY)&.call(response)
          apply_retry_delay(response, provider)
          self.class.parse_error(provider:, response: streaming_error_response(response))
        end
      rescue RubyLLM::Error => e
        apply_raised_retry_delay(env, provider, e)
        raise
      end

      # A rate limit reported inside a stream raises with no failed HTTP
      # status, and without an env on Faraday 1, so its hint is only on the
      # error's own response.
      def apply_raised_retry_delay(env, provider, error)
        return apply_retry_delay(env, provider) unless rate_limit_report?(error)

        env[:streaming_error_response] ||= error.response
        env[:response_headers] ||= Faraday::Utils::Headers.new
        apply_retry_delay(env, provider, status: 429)
      end

      def rate_limit_report?(error)
        return true if error.is_a?(RateLimitError)

        [error.response&.body].flatten.grep(Hash).any? do |part|
          part['error'].is_a?(Hash) && part['error']['code'] == 429
        end
      end

      # The retry middleware only reads the standard Retry-After header, so
      # other retry hints are normalized into seconds here. A failed stream
      # usually raises while it is read, before on_complete, and keeps its
      # body in the stored streaming error rather than on the response.
      def apply_retry_delay(response, provider, status: response_status(response))
        return unless status && status >= 400

        headers = response[:response_headers]
        return unless headers && !headers['Retry-After']

        delay = millisecond_retry_delay(headers) || provider_retry_delay(provider, response, status)
        headers['Retry-After'] = delay.to_s if delay
      end

      def response_status(response)
        response.respond_to?(:status) ? response.status : response[:status]
      end

      def provider_retry_delay(provider, response, status)
        provider&.retry_delay(streaming_error_response(response)) if status == 429
      end

      def millisecond_retry_delay(headers)
        value = Float(headers['retry-after-ms'], exception: false)
        value / 1000 if value&.finite? && value >= 0
      end

      def streaming_error_response(response)
        stored_response = if response.respond_to?(:env) && response.env.respond_to?(:[])
                            response.env[:streaming_error_response]
                          elsif response.respond_to?(:[])
                            response[:streaming_error_response]
                          end

        stored_response || response
      rescue NameError
        response
      end

      class << self
        CONTEXT_LENGTH_PATTERNS = [
          /context length/i,
          /context window/i,
          /exceeds?.*context size/i,
          /maximum context/i,
          /request (?:was )?too large/i,
          /too many tokens/i,
          /token count exceeds/i,
          /input[_\s-]?token/i,
          /input or output tokens? must be reduced/i,
          /reduce the length of messages/i,
          /prompt is too long/i,
          /context limit/i,
          /exceeded model token limit/i,
          /prompt exceeds max length/i,
          /input is too long/i,
          /longer than the maximum model length/i
        ].freeze

        RATE_LIMIT_PATTERNS = [
          /rate limit/i,
          /per minute/i,
          /per hour/i,
          /per day/i,
          /quota exceeded/i,
          /wait before trying again/i
        ].freeze

        OVERLOAD_PATTERNS = [
          /currently overloaded/i
        ].freeze

        PAYMENT_REQUIRED_PATTERNS = [
          /credit balance is too low/i
        ].freeze

        AUTHENTICATION_PATTERNS = [
          /api key not valid/i,
          /incorrect api key/i,
          /security token included in the request is (?:invalid|expired)/i
        ].freeze

        def parse_error(provider:, response:)
          status = failure_status(provider, response)
          return if (200..399).cover?(status)

          message = provider&.parse_error(response)
          raise error_class(message, status).new(response:, provider_message: message,
                                                 **provider_details(provider, response))
        end

        private

        def failure_status(provider, response)
          return response.status unless (200..299).cover?(response.status)

          provider&.error_status(response) || response.status
        end

        def provider_details(provider, response)
          {
            provider: (provider.slug if provider.respond_to?(:slug)),
            error_code: (provider.parse_error_code(response) if provider.respond_to?(:parse_error_code)),
            redact: (provider.config&.redact_error_messages if provider.respond_to?(:config))
          }
        end

        def error_class(message, status)
          case status
          when 400 then bad_request_class(message)
          when 401 then UnauthorizedError
          when 402 then PaymentRequiredError
          when 403 then authentication_failed?(message) ? UnauthorizedError : ForbiddenError
          when 413 then context_length_exceeded?(message) ? ContextLengthExceededError : Error
          when 429 then rate_limit_class(message)
          when 500 then ServerError
          when 502..504 then ServiceUnavailableError
          when 529 then OverloadedError
          else Error
          end
        end

        def bad_request_class(message)
          if authentication_failed?(message) then UnauthorizedError
          elsif context_length_exceeded?(message) then ContextLengthExceededError
          elsif rate_limited?(message) then RateLimitError
          elsif overloaded?(message) then OverloadedError
          elsif payment_required?(message) then PaymentRequiredError
          else BadRequestError
          end
        end

        def rate_limit_class(message)
          return RateLimitError if rate_limited?(message)
          return ContextLengthExceededError if context_length_exceeded?(message)

          RateLimitError
        end

        def context_length_exceeded?(message)
          matches?(message, CONTEXT_LENGTH_PATTERNS)
        end

        def overloaded?(message)
          matches?(message, OVERLOAD_PATTERNS)
        end

        def payment_required?(message)
          matches?(message, PAYMENT_REQUIRED_PATTERNS)
        end

        def rate_limited?(message)
          matches?(message, RATE_LIMIT_PATTERNS)
        end

        def authentication_failed?(message)
          matches?(message, AUTHENTICATION_PATTERNS)
        end

        # Providers hand back whatever their error body holds, which is not
        # always a String: bedrock-mantle nests code, message, and type in a
        # Hash. Match on the rendered text so any shape classifies.
        def matches?(message, patterns)
          text = message.to_s
          return false if text.empty?

          patterns.any? { |pattern| text.match?(pattern) }
        end
      end
    end
  end
end

Faraday::Middleware.register_middleware(llm_errors: RubyLLM::Transport::ErrorMiddleware)

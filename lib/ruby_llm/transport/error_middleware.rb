# frozen_string_literal: true

require 'faraday'
require 'ruby_llm/error'

module RubyLLM
  module Transport # :nodoc:
    class ErrorMiddleware < Faraday::Middleware # :nodoc: all
      def initialize(app, options = {})
        super(app)
        @provider = options[:provider]
      end

      # Sits directly above the adapter, inside the retry middleware, so this
      # runs once per attempt: streaming state stored on the env by a previous
      # attempt must not leak into the next one.
      def call(env)
        env[:streaming_error_response] = nil
        env[:streaming_state] = nil
        @app.call(env).on_complete do |response|
          apply_retry_delay(response)
          self.class.parse_error(provider: @provider, response: streaming_error_response(response))
        end
      end

      private

      # The retry middleware only reads the standard Retry-After header, so
      # other retry hints are normalized into seconds here.
      def apply_retry_delay(response)
        status = response.respond_to?(:status) ? response.status : response[:status]
        return unless status && status >= 400

        headers = response[:response_headers]
        return unless headers && !headers['Retry-After']

        delay = millisecond_retry_delay(headers) || provider_retry_delay(response, status)
        headers['Retry-After'] = delay.to_s if delay
      end

      def provider_retry_delay(response, status)
        @provider&.retry_delay(response) if status == 429
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
          /request too large/i,
          /too many tokens/i,
          /token count exceeds/i,
          /input[_\s-]?token/i,
          /input or output tokens? must be reduced/i,
          /reduce the length of messages/i,
          /prompt is too long/i,
          /context limit/i
        ].freeze

        RATE_LIMIT_PATTERNS = [
          /rate limit/i,
          /per minute/i,
          /per hour/i,
          /per day/i
        ].freeze

        # OpenAI has returned capacity failures as HTTP 400 ("Our servers are
        # currently overloaded. Please try again later."). Status 529 is the
        # only code that maps to OverloadedError on its own, so match the
        # message the same way a 400 context-length error is reclassified.
        OVERLOAD_PATTERNS = [
          /overloaded/i
        ].freeze

        def parse_error(provider:, response:)
          message = provider&.parse_error(response)

          case response.status
          when 200..399
            message
          when 400
            classify_bad_request!(message, response)
          when 401
            raise UnauthorizedError.new(message, response:)
          when 402
            raise PaymentRequiredError.new(message, response:)
          when 403
            raise ForbiddenError.new(message, response:)
          when 429
            raise RateLimitError.new(message, response:) if rate_limited?(message)
            raise ContextLengthExceededError.new(message, response:) if context_length_exceeded?(message)

            raise RateLimitError.new(message, response:)
          when 500
            raise ServerError.new(message, response:)
          when 502..504
            raise ServiceUnavailableError.new(message, response:)
          when 529
            raise OverloadedError.new(message, response:)
          else
            raise Error.new(message, response:)
          end
        end

        private

        # Providers hand back whatever their error body holds, which is not
        # always a String: bedrock-mantle nests code, message, and type in a
        # Hash. Match on the rendered text so any shape classifies.
        def context_length_exceeded?(message)
          text = message.to_s
          return false if text.empty?

          CONTEXT_LENGTH_PATTERNS.any? { |pattern| text.match?(pattern) }
        end

        def classify_bad_request!(message, response)
          raise ContextLengthExceededError.new(message, response:) if context_length_exceeded?(message)
          raise OverloadedError.new(message, response:) if overloaded?(message)

          raise BadRequestError.new(message, response:)
        end

        def overloaded?(message)
          text = message.to_s
          return false if text.empty?

          OVERLOAD_PATTERNS.any? { |pattern| text.match?(pattern) }
        end

        def rate_limited?(message)
          text = message.to_s
          return false if text.empty?

          RATE_LIMIT_PATTERNS.any? { |pattern| text.match?(pattern) }
        end
      end
    end
  end
end

Faraday::Middleware.register_middleware(llm_errors: RubyLLM::Transport::ErrorMiddleware)

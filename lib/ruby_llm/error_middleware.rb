# frozen_string_literal: true

require 'faraday'
require 'ruby_llm/error'

module RubyLLM
  class ErrorMiddleware < Faraday::Middleware # :nodoc: all
    def initialize(app, options = {})
      super(app)
      @provider = options[:provider]
    end

    def call(env)
      @app.call(env).on_complete do |response|
        self.class.parse_error(provider: @provider, response: streaming_error_response(response))
      end
    end

    private

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
        /maximum context/i,
        /request too large/i,
        /too many tokens/i,
        /token count exceeds/i,
        /input[_\s-]?token/i,
        /input or output tokens? must be reduced/i,
        /reduce the length of messages/i,
        /prompt is too long/i
      ].freeze

      RATE_LIMIT_PATTERNS = [
        /rate limit/i,
        /per minute/i,
        /per hour/i,
        /per day/i
      ].freeze

      def parse_error(provider:, response:)
        message = provider&.parse_error(response)

        case response.status
        when 200..399
          message
        when 400
          raise ContextLengthExceededError.new(message, response:) if context_length_exceeded?(message)

          raise BadRequestError.new(message, response:)
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

      def context_length_exceeded?(message)
        return false if message.to_s.empty?

        CONTEXT_LENGTH_PATTERNS.any? { |pattern| message.match?(pattern) }
      end

      def rate_limited?(message)
        return false if message.to_s.empty?

        RATE_LIMIT_PATTERNS.any? { |pattern| message.match?(pattern) }
      end
    end
  end
end

Faraday::Middleware.register_middleware(llm_errors: RubyLLM::ErrorMiddleware)

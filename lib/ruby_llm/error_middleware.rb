# frozen_string_literal: true

require 'faraday'
require 'ruby_llm/error'

module RubyLLM
  # Faraday middleware that maps provider-specific API errors to RubyLLM errors.
  class ErrorMiddleware < Faraday::Middleware
    def initialize(app, options = {})
      super(app)
      @provider = options[:provider]
    end

    def call(env)
      @app.call(env).on_complete do |response|
        self.class.parse_error(provider: @provider, response: response)
      end
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
          raise ContextLengthExceededError.new(response, message) if context_length_exceeded?(message)

          raise BadRequestError.new(response, message)
        when 401
          raise UnauthorizedError.new(response, message)
        when 402
          raise PaymentRequiredError.new(response, message)
        when 403
          raise ForbiddenError.new(response, message)
        when 429
          raise RateLimitError.new(response, message) if rate_limited?(message)
          raise ContextLengthExceededError.new(response, message) if context_length_exceeded?(message)

          raise RateLimitError.new(response, message)
        when 500
          raise ServerError.new(response, message)
        when 502..504
          raise ServiceUnavailableError.new(response, message)
        when 529
          raise OverloadedError.new(response, message)
        else
          raise Error.new(response, message)
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

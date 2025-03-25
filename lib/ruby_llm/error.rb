# frozen_string_literal: true

module RubyLLM
  # Custom error class that wraps API errors from different providers
  # into a consistent format with helpful error messages.
  #
  # Example:
  #   begin
  #     chat.ask "What's 2+2?"
  #   rescue RubyLLM::Error => e
  #     puts "Couldn't chat with AI: #{e.message}"
  #   end
  class Error < StandardError
    attr_reader :response

    def initialize(response = nil, message = nil)
      @response = response
      super(message || response&.body)
    end
  end

  class ModelNotFoundError < StandardError; end
  class InvalidRoleError < StandardError; end
  class UnsupportedFunctionsError < StandardError; end
  class ConfigurationError < StandardError; end
  class UnauthorizedError < Error; end
  class PaymentRequiredError < Error; end
  class ServiceUnavailableError < Error; end
  class BadRequestError < Error; end
  class RateLimitError < Error; end
  class ServerError < Error; end

  # Faraday middleware that maps provider-specific API errors to RubyLLM errors.
  # Uses provider's parse_error method to extract meaningful error messages.
  class ErrorMiddleware < Faraday::Middleware
    def initialize(app, provider:)
      super(app)
      @provider = provider
    end

    def call(env)
      @app.call(env).on_complete do |response|
        self.class.parse_error(provider: @provider, response: response)
      end
    end

    class << self
      def parse_error(provider:, response:) # rubocop:disable Metrics/CyclomaticComplexity,Metrics/MethodLength,Metrics/AbcSize,Metrics/PerceivedComplexity
        message = provider&.parse_error(response)

        case response.status
        when 200..399
          message
        when 400
          raise BadRequestError.new(response, message || 'Invalid request - please check your input')
        when 401
          raise UnauthorizedError.new(response, message || 'Invalid API key - check your credentials')
        when 402
          raise PaymentRequiredError.new(response, message || 'Payment required - please top up your account')
        when 429
          raise RateLimitError.new(response, message || 'Rate limit exceeded - please wait a moment')
        when 500
          raise ServerError.new(response, message || 'API server error - please try again')
        when 502..503
          raise ServiceUnavailableError.new(response, message || 'API server unavailable - please try again later')
        else
          raise Error.new(response, message || 'An unknown error occurred')
        end
      end
    end
  end
end

Faraday::Middleware.register_middleware(llm_errors: RubyLLM::ErrorMiddleware)

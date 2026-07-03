# frozen_string_literal: true

module RubyLLM
  # Custom error class that wraps API errors from different providers
  # into a consistent format with helpful error messages.
  class Error < StandardError
    attr_reader :response

    def self.default_message
      nil
    end

    def initialize(response = nil, message = nil)
      if response.is_a?(String)
        message = response
        response = nil
      end

      @response = response
      super(message || response&.body || self.class.default_message)
    end
  end

  # Error classes for non-HTTP errors
  class ConfigurationError < StandardError; end
  class PromptNotFoundError < StandardError; end
  class InvalidRoleError < StandardError; end
  class InvalidToolChoiceError < StandardError; end
  class ModelNotFoundError < StandardError; end

  # Raised when RubyLLM cannot format an attachment for the selected provider.
  class UnsupportedAttachmentError < StandardError
    GUIDANCE = 'Consider using a model that supports this attachment type.'

    def initialize(type = nil)
      message = 'Unsupported attachment type'
      message = "#{message}: #{type}" if type
      super("#{message}. #{GUIDANCE}")
    end
  end

  # Error classes for different HTTP status codes
  # Raised when the API request is invalid.
  class BadRequestError < Error
    def self.default_message
      'Invalid request - please check your input'
    end
  end

  # Raised when the API key or account lacks permission for the request.
  class ForbiddenError < Error
    def self.default_message
      'Forbidden - you do not have permission to access this resource'
    end
  end

  # Raised when token or context limits are exceeded for a request.
  class ContextLengthExceededError < Error
    def self.default_message
      'Context length exceeded'
    end
  end

  # Raised when the service signals temporary overload.
  class OverloadedError < Error
    def self.default_message
      'Service overloaded - please try again later'
    end
  end

  # Raised when account billing prevents the request from being completed.
  class PaymentRequiredError < Error
    def self.default_message
      'Payment required - please top up your account'
    end
  end

  # Raised when rate limits are exceeded.
  class RateLimitError < Error
    def self.default_message
      'Rate limit exceeded - please wait a moment'
    end
  end

  # Raised when the provider returns a server-side error.
  class ServerError < Error
    def self.default_message
      'API server error - please try again'
    end
  end

  # Raised when the provider is temporarily unavailable.
  class ServiceUnavailableError < Error
    def self.default_message
      'API server unavailable - please try again later'
    end
  end

  # Raised when authentication fails.
  class UnauthorizedError < Error
    def self.default_message
      'Invalid API key - check your credentials'
    end
  end
end

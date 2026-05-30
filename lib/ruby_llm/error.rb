# frozen_string_literal: true

module RubyLLM
  # Custom error class that wraps API errors from different providers
  # into a consistent format with helpful error messages.
  class Error < StandardError
    attr_reader :response

    def initialize(response = nil, message = nil)
      if response.is_a?(String)
        message = response
        response = nil
      end

      @response = response
      super(message || response&.body)
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
  class BadRequestError < Error; end
  class ForbiddenError < Error; end
  class ContextLengthExceededError < Error; end
  class OverloadedError < Error; end
  class PaymentRequiredError < Error; end
  class RateLimitError < Error; end
  class ServerError < Error; end
  class ServiceUnavailableError < Error; end
  class UnauthorizedError < Error; end
end

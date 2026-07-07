# frozen_string_literal: true

module RubyLLM
  # Error is the base class for provider-operation errors raised by
  # RubyLLM, including API, network, capability, and provider response-shape
  # failures. When an HTTP response is available, it wraps that response and
  # normalizes the message across providers. Subclasses map common HTTP
  # status codes: BadRequestError (400), UnauthorizedError (401),
  # PaymentRequiredError (402), ForbiddenError (403), RateLimitError (429),
  # ServerError (500), ServiceUnavailableError (502 to 504), and
  # OverloadedError (529).
  #
  #   begin
  #     RubyLLM.chat.ask "Translate 'hello' to French."
  #   rescue RubyLLM::RateLimitError
  #     puts "Rate limit hit. Please wait a moment."
  #   rescue RubyLLM::Error => e
  #     puts "API error: #{e.message}"
  #     puts e.response&.status
  #   end
  #
  # Local setup and programming errors, such as ConfigurationError and
  # ModelNotFoundError, inherit from StandardError directly and are not
  # caught by rescuing Error.
  class Error < StandardError
    # The HTTP response that caused the error, or +nil+ when none is
    # available. Its +status+ and +body+ carry the provider's reply.
    attr_reader :response

    def self.default_message # :nodoc:
      nil
    end

    # Creates an error with +message+. Pass +response:+ to attach the HTTP
    # response; its body supplies the message when +message+ is +nil+.
    def initialize(message = nil, response: nil)
      @response = response
      super(message || response&.body || self.class.default_message)
    end
  end

  # Raised when required configuration, such as a provider API key, is
  # missing.
  class ConfigurationError < StandardError; end

  # Raised when RubyLLM.render_prompt cannot find the named prompt file.
  class PromptNotFoundError < StandardError; end

  # Raised when a message role outside +:system+, +:user+, +:assistant+, or
  # +:tool+ is used.
  class InvalidRoleError < StandardError; end

  # Raised when the +choice:+ option of Chat#with_tool_options is neither a
  # known mode nor the name of a registered tool.
  class InvalidToolChoiceError < StandardError; end

  # Raised when a requested model id is not in the model registry.
  class ModelNotFoundError < StandardError; end

  # Raised when an attachment cannot be formatted for the selected provider,
  # for example an audio file sent to a model without audio input.
  class UnsupportedAttachmentError < Error
    GUIDANCE = 'Consider using a model that supports this attachment type.' # :nodoc:

    def initialize(type = nil) # :nodoc:
      message = 'Unsupported attachment type'
      message = "#{message}: #{type}" if type
      super("#{message}. #{GUIDANCE}")
    end
  end

  # Raised for HTTP 400 responses when the request is invalid.
  class BadRequestError < Error
    def self.default_message # :nodoc:
      'Invalid request - please check your input'
    end
  end

  # Raised for HTTP 403 responses when the API key lacks permission for the
  # requested resource.
  class ForbiddenError < Error
    def self.default_message # :nodoc:
      'Forbidden - you do not have permission to access this resource'
    end
  end

  # Raised when the request exceeds the model's context window or token
  # limits.
  class ContextLengthExceededError < Error
    def self.default_message # :nodoc:
      'Context length exceeded'
    end
  end

  # Raised when a provider returns tool-call arguments that are not valid
  # JSON, often because the response was truncated mid-tool-call.
  class ToolCallParseError < Error
    attr_reader :finish_reason

    def initialize(message = nil, response: nil, finish_reason: nil) # :nodoc:
      @finish_reason = finish_reason
      message ||= 'Provider returned malformed tool call arguments'
      message = "#{message} (finish_reason: #{finish_reason})" if finish_reason
      super(message, response: response)
    end
  end

  # Raised for HTTP 529 responses when the provider is temporarily
  # overloaded.
  class OverloadedError < Error
    def self.default_message # :nodoc:
      'Service overloaded - please try again later'
    end
  end

  # Raised for HTTP 402 responses when the provider account has a billing
  # or quota problem.
  class PaymentRequiredError < Error
    def self.default_message # :nodoc:
      'Payment required - please top up your account'
    end
  end

  # Raised for HTTP 429 responses when the provider rate limit is exceeded.
  class RateLimitError < Error
    def self.default_message # :nodoc:
      'Rate limit exceeded - please wait a moment'
    end
  end

  # Raised for HTTP 500 responses when the provider reports a server error.
  class ServerError < Error
    def self.default_message # :nodoc:
      'API server error - please try again'
    end
  end

  # Raised for HTTP 502, 503, and 504 responses when the provider is
  # temporarily unavailable.
  class ServiceUnavailableError < Error
    def self.default_message # :nodoc:
      'API server unavailable - please try again later'
    end
  end

  # Raised for HTTP 401 responses when the API key is missing or invalid.
  class UnauthorizedError < Error
    def self.default_message # :nodoc:
      'Invalid API key - check your credentials'
    end
  end
end

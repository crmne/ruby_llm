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
  # Providers often quote the request back in their error, so with
  # Configuration#redact_error_messages the message carries only the HTTP
  # status, the provider, and the provider's error code. What the provider
  # wrote stays on #provider_message and its raw body on #response_body.
  #
  # Local setup and programming errors, such as ConfigurationError and
  # ModelNotFoundError, inherit from StandardError directly and are not
  # caught by rescuing Error.
  class Error < StandardError
    # The HTTP response that caused the error, or +nil+ when none is
    # available. Its +status+ and +body+ carry the provider's reply.
    attr_reader :response

    # The slug of the provider that answered, such as <tt>"openai"</tt>, or
    # +nil+ when it is not known.
    attr_reader :provider

    # The provider's code for the error, such as
    # <tt>"invalid_request_error"</tt> or <tt>"INVALID_ARGUMENT"</tt>, or
    # +nil+ when it gave none that reads like a code.
    attr_reader :error_code

    # What the provider wrote about the error, or +nil+ when it wrote
    # nothing RubyLLM could read. It can quote the request, so
    # Configuration#redact_error_messages keeps it out of #message.
    attr_reader :provider_message

    # The Protocol that rendered the request the error answered, which
    # reads its payload back for #request_shape.
    attr_accessor :request_protocol # :nodoc:

    # The payload request_protocol rendered for the request.
    attr_accessor :request_payload # :nodoc:

    def self.default_message # :nodoc:
      nil
    end

    ERROR_CODE = /\A[A-Za-z][\w.:-]{0,63}\z/ # :nodoc:

    # Creates an error with +message+. Pass +response:+ to attach the HTTP
    # response, +provider:+ to name the provider's slug, +error_code:+ for
    # the provider's code, kept only when it reads like one, and
    # +provider_message:+ for what the provider wrote, which follows
    # +message+, or stands in for it when +message+ is +nil+. Without
    # either, the response body supplies the message.
    def initialize(message = nil, response: nil, provider: nil, provider_message: nil, error_code: nil, redact: nil)
      @response = response
      @provider = provider
      @provider_message = provider_message
      @error_code = error_code if error_code.is_a?(Integer) || error_code.to_s.match?(ERROR_CODE)
      redact = RubyLLM.config.redact_error_messages if redact.nil?
      super(full_message_for(message, redact:) || self.class.default_message)
    end

    # Returns the body of #response, or +nil+ without one. It can quote the
    # request, so Configuration#redact_error_messages keeps it out of
    # #message.
    def response_body
      response&.body
    end

    # Returns a RequestShape describing the conversation request the error
    # answered: each turn's parts and their sizes, never their contents,
    # and the problems providers are known to refuse. Returns +nil+ for
    # errors raised before a request goes out, such as an unsupported
    # attachment, and for operations that send no conversation, such as
    # embeddings.
    #
    #   rescue RubyLLM::BadRequestError => e
    #     Rails.logger.error("#{e.message}\n#{e.request_shape}")
    #     Rails.error.report(e, context: { request_shape: e.request_shape&.to_h })
    #
    def request_shape # :nodoc:
      return unless request_protocol
      return @request_shape if defined?(@request_shape)

      @request_shape = request_protocol.request_shape(request_payload)
    end

    private

    def full_message_for(message, redact:)
      return message || (redacted_message if remote?) if redact
      return "#{message}: #{provider_message}" if message && provider_message

      message || provider_message || response_body_message
    end

    def remote?
      !response.nil? || !provider_message.nil?
    end

    def redacted_message
      status = response.status if response.respond_to?(:status)
      text = "#{provider || redacted_source} returned #{status ? "HTTP #{status}" : 'an error'}"
      error_code ? "#{text} (#{error_code})" : text
    end

    def redacted_source
      'The provider'
    end

    def response_body_message
      body = response_body
      body unless body.respond_to?(:empty?) && body.empty?
    end
  end

  # Raised when a deprecated API is used and
  # Configuration#deprecation_behavior is +:raise+. With the default
  # +:warn+, deprecations are logged instead.
  #
  #   RubyLLM.configure do |config|
  #     config.deprecation_behavior = :raise
  #   end
  class DeprecationError < StandardError; end

  # Raised when required configuration, such as a provider API key, is
  # missing, or when a setup can't do what a chat asks of it, such as a
  # subagent added with +tools+ that stops to wait (see AgentTool).
  class ConfigurationError < StandardError; end

  # Raised when RubyLLM.render_prompt cannot find the named prompt file.
  class PromptNotFoundError < StandardError; end

  # Raised when a skill named by Chat#with_skills or Skill.find is missing.
  class SkillNotFoundError < StandardError; end

  # Raised when a skill's +SKILL.md+ breaks the Agent Skills specification:
  # missing or malformed front matter, or a name or description it rejects.
  class InvalidSkillError < StandardError; end

  # Raised when a FileStore has no file at the path asked for.
  class FileNotFoundError < StandardError; end

  # Raised by a FileStore when a write would take it past its limit. Its
  # message is what the model reads, so say what to do. The file tools and
  # +run_code+ answer the model with it instead of failing the reply.
  class FileStoreFullError < StandardError; end

  # Raised when a message role outside +:system+, +:user+, +:assistant+, or
  # +:tool+ is used.
  class InvalidRoleError < StandardError; end

  # Raised when the +choice:+ option of Chat#with_tool_options is neither a
  # known mode nor the name of a registered tool.
  class InvalidToolChoiceError < StandardError; end

  # Raised when a user message is staged while the last response still has
  # unanswered tool calls. Providers reject such a transcript, so the chat
  # refuses it up front: finish the round with #complete, recording
  # #approve or #decline decisions for calls that require approval.
  class PendingToolCallsError < StandardError; end

  # Raised when a persisted tool call is declined after it started running.
  # The call keeps running and the model receives its result.
  class ToolCallRunningError < StandardError; end

  # Raised when a requested model id is not in the model registry.
  class ModelNotFoundError < StandardError; end

  # Raised when a model registry cannot be fetched, parsed, or persisted.
  class ModelRegistryError < StandardError; end

  # Raised when an in-flight chat operation is cancelled with Chat#cancel.
  class CancelledError < StandardError
    # Creates an error for a cancelled chat operation.
    def initialize(message = 'Chat generation cancelled')
      super
    end
  end

  # Raised when Chat#with_provider_tools is used with a provider RubyLLM has
  # no server-tool support for, or with an alias the provider's protocol
  # does not define.
  class UnsupportedServerToolError < Error; end

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

  # Raised when the provider rejects a request because the model does not
  # take one of its parameters, such as a temperature on a reasoning model.
  # Chat#with_fallbacks can retry without it with <tt>drop_unsupported: true</tt>.
  class UnsupportedParameterError < BadRequestError
    # The parameter the provider rejected: a Symbol naming the RubyLLM
    # setting, such as +:temperature+, +:thinking+, or +:max_output_tokens+,
    # or the provider's own name as a String for anything else, such as a
    # key of Chat#with_provider_options.
    attr_reader :parameter

    # Creates the error for +parameter+. Takes the other arguments of
    # Error.new.
    def initialize(message = nil, parameter: nil, **)
      @parameter = parameter
      super(message, **)
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

  # The parent of ToolCallTruncatedError, the error RubyLLM raises for
  # tool-call arguments it cannot read. Other arguments that are not a JSON
  # object do not raise: the chat answers the call with an error result
  # and the model calls the tool again.
  class ToolCallParseError < Error
    # Returns the normalized reason generation stopped, or +nil+.
    attr_reader :finish_reason

    def initialize(message = nil, response: nil, finish_reason: nil) # :nodoc:
      @finish_reason = finish_reason
      super(message || default_message, response: response)
    end

    private

    def default_message
      message = 'Provider returned malformed tool call arguments'
      finish_reason ? "#{message} (finish_reason: #{finish_reason})" : message
    end
  end

  # Raised when the response reached its output token limit while the model
  # was writing a tool call, so the call's arguments are incomplete. Raise
  # the limit with Chat#with_max_output_tokens, or ask for less at once.
  class ToolCallTruncatedError < ToolCallParseError
    def initialize(message = nil, response: nil) # :nodoc:
      super(message, response:, finish_reason: :max_tokens)
    end

    private

    def default_message
      'The response reached its output token limit while writing a tool call (finish_reason: max_tokens)'
    end
  end

  # Raised when the provider's content filters block a transcription and
  # no transcript comes back. The message names the provider's reason,
  # such as +SAFETY+. Chat responses report a block through
  # Message#content_filtered? instead of raising.
  class ContentFilterError < Error; end

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

  # Raised when a request never gets an answer from the provider or an
  # MCP server: the connection is refused or drops, TLS fails, or the
  # request times out. RubyLLM retries provider requests first, following
  # Configuration#max_retries. The original Faraday error is its +cause+.
  #
  #   rescue RubyLLM::ConnectionError => e
  #     retry_later if e.timeout?
  class ConnectionError < Error
    # Returns whether the request timed out, including while opening the
    # connection or waiting for the next bytes of a stream, rather than
    # failing to connect.
    def timeout?
      return true if cause.is_a?(Faraday::TimeoutError)

      cause.respond_to?(:wrapped_exception) && TIMEOUTS.any? { |timeout| cause.wrapped_exception.is_a?(timeout) }
    end

    # Some adapters, such as async-http-faraday, report a read that waited
    # too long as a failed connection wrapping IO::TimeoutError.
    TIMEOUTS = [Timeout::Error, IO::TimeoutError].freeze # :nodoc:
    private_constant :TIMEOUTS
  end

  # Raised for HTTP 401 responses when the API key is missing or invalid.
  class UnauthorizedError < Error
    def self.default_message # :nodoc:
      'Invalid API key - check your credentials'
    end
  end
end

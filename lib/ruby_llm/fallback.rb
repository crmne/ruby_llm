# frozen_string_literal: true

module RubyLLM
  # A Fallback is a fallback model target configured with Chat#with_fallbacks.
  # When the active model fails with a matching error, the chat retries the
  # request with each fallback in order. Instances are yielded to
  # Chat#before_fallback and Chat#after_fallback callbacks, enriched with the
  # details of that attempt.
  #
  #   chat = RubyLLM.chat(model: "gpt-4.1")
  #                 .with_fallbacks("gpt-4.1-mini", "claude-haiku-4-5")
  #
  #   chat.before_fallback do |fallback|
  #     puts "Falling back from #{fallback.from.id} to #{fallback.to.id}"
  #   end
  #
  #   chat.after_fallback do |fallback|
  #     puts "Fallback #{fallback.succeeded? ? 'succeeded' : 'failed'}"
  #   end
  class Fallback
    # The error classes that trigger a fallback when Chat#with_fallbacks is
    # called without +on:+.
    DEFAULT_ERRORS = [
      RateLimitError,
      ServerError,
      ServiceUnavailableError,
      OverloadedError,
      Faraday::TimeoutError,
      Faraday::ConnectionFailed
    ].freeze

    # The model id of the fallback target.
    attr_reader :id

    # The provider of the fallback target as a Symbol, or +nil+.
    attr_reader :provider

    # The Model object the fallback was configured with, or +nil+ when it was
    # configured with a model id.
    attr_reader :model

    # The Chat performing the fallback attempt.
    attr_reader :chat

    # The error that triggered the fallback.
    attr_reader :error

    # The Model the chat is falling back from.
    attr_reader :from

    # The Model the chat is falling back to.
    attr_reader :to

    # The fallback attempt number, starting at 1.
    attr_reader :attempt

    # The response Message from a successful fallback attempt, or +nil+.
    attr_reader :response

    # The error raised by the fallback attempt itself, or +nil+ if it
    # succeeded.
    attr_reader :fallback_error

    attr_reader :streaming # :nodoc:

    def self.build(value) # :nodoc:
      case value
      when self
        value
      when RubyLLM::Model
        new(model: value)
      when String, Symbol
        new(id: value.to_s)
      else
        raise ArgumentError, 'Expected a model id or RubyLLM::Model'
      end
    end

    def initialize(id: nil, provider: nil, model: nil, **attributes) # :nodoc:
      @id = id || model&.id
      @provider = (provider || model&.provider)&.to_sym
      @model = model
      @chat = attributes[:chat]
      @error = attributes[:error]
      @from = attributes[:from]
      @to = attributes[:to]
      @attempt = attributes[:attempt]
      @streaming = attributes.fetch(:streaming, false)
      @chunks_yielded = attributes.fetch(:chunks_yielded, false)
      @response = attributes[:response]
      @fallback_error = attributes[:fallback_error]
    end

    def with_attempt(**attributes) # :nodoc:
      self.class.new(id: id, provider: provider, model: model, **attributes)
    end

    def finish(response: nil, fallback_error: nil) # :nodoc:
      @response = response
      @fallback_error = fallback_error
      self
    end

    # Returns whether the fallback happened during a streaming request.
    def streaming?
      streaming
    end

    # Returns whether the failed model already yielded stream chunks before
    # the fallback.
    def chunks_yielded?
      @chunks_yielded
    end

    # Returns +true+ if the fallback attempt raised an error, +false+
    # otherwise.
    def failed?
      !fallback_error.nil?
    end

    # Returns +true+ if the fallback attempt produced a response without
    # error, +false+ otherwise.
    def succeeded?
      !response.nil? && !failed?
    end
  end
end

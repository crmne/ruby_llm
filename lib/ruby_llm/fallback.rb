# frozen_string_literal: true

module RubyLLM
  # A model fallback target, enriched with runtime attempt details when used.
  class Fallback
    DEFAULT_ERRORS = [
      RateLimitError,
      ServerError,
      ServiceUnavailableError,
      OverloadedError,
      Faraday::TimeoutError,
      Faraday::ConnectionFailed
    ].freeze

    attr_reader :id, :provider, :model, :chat, :error, :from, :to, :attempt, :streaming, :response,
                :fallback_error

    def self.build(value)
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

    def initialize(id: nil, provider: nil, model: nil, **attributes)
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

    def with_attempt(**attributes)
      self.class.new(id: id, provider: provider, model: model, **attributes)
    end

    def finish(response: nil, fallback_error: nil)
      @response = response
      @fallback_error = fallback_error
      self
    end

    def streaming?
      streaming
    end

    def chunks_yielded?
      @chunks_yielded
    end

    def failed?
      !fallback_error.nil?
    end

    def succeeded?
      !response.nil? && !failed?
    end
  end
end

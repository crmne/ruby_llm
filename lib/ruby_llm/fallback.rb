# frozen_string_literal: true

module RubyLLM
  # Handles model-level failover for transient errors.
  # Included by Chat to keep fallback logic out of the main conversation flow.
  module Fallback
    ERRORS = [
      RateLimitError,
      ServerError,
      ServiceUnavailableError,
      OverloadedError,
      Faraday::TimeoutError,
      Faraday::ConnectionFailed
    ].freeze

    def with_fallback(model_id, provider: nil)
      @fallback = { model: model_id, provider: provider }
      self
    end

    private

    def with_fallback_protection(&)
      yield
    rescue *ERRORS => e
      attempt_fallback(e, &)
    end

    def attempt_fallback(error, &)
      raise error unless @fallback && !@in_fallback

      log_fallback(error)

      original_model = @model
      original_provider = @provider
      original_connection = @connection

      begin
        @in_fallback = true
        with_model(@fallback[:model], provider: @fallback[:provider])
        yield
      rescue *ERRORS => fallback_error
        log_fallback_failure(fallback_error)
        raise error
      ensure
        @in_fallback = false
        @model = original_model
        @provider = original_provider
        @connection = original_connection
      end
    end

    def log_fallback(error)
      RubyLLM.logger.warn "RubyLLM: #{error.class} on #{sanitize_for_log(@model.id)}, " \
                           "falling back to #{sanitize_for_log(@fallback[:model])}"
    end

    def log_fallback_failure(error)
      RubyLLM.logger.warn "RubyLLM: Fallback to #{sanitize_for_log(@fallback[:model])} also failed: " \
                           "#{error.class} - #{sanitize_for_log(error.message)}"
    end

    def sanitize_for_log(value)
      value.to_s.gsub(/[\x00-\x1f\x7f]/, '')
    end
  end
end

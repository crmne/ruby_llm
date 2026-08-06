# frozen_string_literal: true

require 'faraday'

module RubyLLM
  # Sits inside Faraday retry middleware so every transport attempt produces
  # one usage observation.
  class UsageMiddleware < Faraday::Middleware # :nodoc: all
    CONTEXT_KEY = :ruby_llm_usage_tracker

    def call(env)
      tracker = env.request.context&.[](CONTEXT_KEY)
      return @app.call(env) unless tracker

      entry = tracker.start
      begin
        @app.call(env)
      rescue StandardError => e
        tracker.fail_attempt(entry, e)
        raise
      end
    end
  end
end

Faraday::Middleware.register_middleware(llm_usage: RubyLLM::UsageMiddleware)

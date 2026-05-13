# frozen_string_literal: true

module RubyLLM
  # Emits structured RubyLLM events without requiring a specific observability
  # backend. Rails apps can use ActiveSupport::Notifications as the instrumenter.
  module Instrumentation
    module_function

    def instrument(name, payload = nil, config: nil, **attributes)
      payload = build_payload(payload, attributes)
      instrumenter = instrumenter_for(config)
      return yield(payload) if block_given? && !instrumenter

      unless instrumenter.respond_to?(:instrument)
        return yield(payload) if block_given?

        return
      end

      if block_given?
        instrumenter.instrument(name, payload) { yield(payload) }
      else
        instrumenter.instrument(name, payload)
      end
    end

    def build_payload(payload, attributes)
      payload ||= {}
      attributes.empty? ? payload : payload.merge(attributes)
    end

    def instrumenter_for(config)
      (config || RubyLLM.config).instrumenter
    end
  end
end

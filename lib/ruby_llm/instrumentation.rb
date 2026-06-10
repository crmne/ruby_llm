# frozen_string_literal: true

module RubyLLM
  # Emits structured RubyLLM events without requiring a specific observability
  # backend. Rails apps can use ActiveSupport::Notifications as the instrumenter.
  module Instrumentation
    module_function

    def instrument(name, payload = nil, config: nil, **attributes) # rubocop:disable Metrics/PerceivedComplexity
      payload ||= {}
      payload = payload.merge(attributes) unless attributes.empty?
      instrumenter = (config || RubyLLM.config).instrumenter

      if instrumenter.respond_to?(:instrument)
        if block_given?
          instrumenter.instrument(name, payload) { yield(payload) }
        else
          instrumenter.instrument(name, payload)
        end
      elsif block_given?
        yield(payload)
      end
    end
  end
end

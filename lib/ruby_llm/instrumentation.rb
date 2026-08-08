# frozen_string_literal: true

module RubyLLM
  module Instrumentation # :nodoc:
    WORKFLOW_CONTEXT_KEY = :ruby_llm_workflow_context

    module_function

    def instrument(name, payload = nil, config: nil, **attributes) # rubocop:disable Metrics/PerceivedComplexity
      payload ||= {}
      payload = payload.merge(attributes) unless attributes.empty?
      workflow_context = current_workflow
      payload = payload.merge(workflow_context) if workflow_context
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

    def current_workflow
      Thread.current[WORKFLOW_CONTEXT_KEY]
    end

    def with_workflow(context)
      previous_context = current_workflow
      Thread.current[WORKFLOW_CONTEXT_KEY] = context
      yield
    ensure
      Thread.current[WORKFLOW_CONTEXT_KEY] = previous_context
    end
  end
end

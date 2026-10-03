# frozen_string_literal: true

module RubyLLM
  module Support # :nodoc:
    module Instrumentation # :nodoc:
      WORKFLOW_CONTEXT_KEY = :ruby_llm_workflow_context

      @subscribers = [].freeze
      @mutex = Mutex.new

      module_function

      def instrument(name, payload = nil, config: nil, **attributes, &block)
        payload ||= {}
        payload = payload.merge(attributes) unless attributes.empty?
        workflow_context = current_workflow
        payload = payload.merge(workflow_context) if workflow_context
        instrumenter = (config || RubyLLM.config).instrumenter
        subscribers = @subscribers
        return dispatch(instrumenter, name, payload, &block) if subscribers.empty?

        dispatch = -> { dispatch(instrumenter, name, payload, &block) }
        subscribers.reverse_each do |subscriber|
          inner = dispatch
          dispatch = -> { subscriber.instrument(name, payload, &inner) }
        end
        dispatch.call
      end

      def subscribe(subscriber)
        @mutex.synchronize { @subscribers = (@subscribers | [subscriber]).freeze }
      end

      def unsubscribe(subscriber)
        @mutex.synchronize { @subscribers = (@subscribers - [subscriber]).freeze }
      end

      def capture_context
        @subscribers.filter_map do |subscriber|
          [subscriber, subscriber.capture_context] if subscriber.respond_to?(:capture_context)
        end
      end

      def with_context(context, &block)
        context.reverse_each do |subscriber, value|
          inner = block
          block = -> { subscriber.with_context(value, &inner) }
        end
        block.call
      end

      def dispatch(instrumenter, name, payload)
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
      private_class_method :dispatch

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
end

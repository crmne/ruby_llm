# frozen_string_literal: true

module RubyLLM
  class Chat
    module ToolConcurrency # :nodoc: all
      MODES = %i[threads fibers].freeze
      Result = Struct.new(:index, :tool_call, :value, :error, keyword_init: true)

      module_function

      def run(mode, tool_calls, on_result: nil, &)
        case mode
        when :threads
          run_with_threads(tool_calls, on_result:, &)
        when :fibers
          run_with_fibers(tool_calls, on_result:, &)
        end
      end

      def run_with_threads(tool_calls, on_result:, &execute)
        caller_context = execution_context
        workflow_context = Support::Instrumentation.current_workflow
        queue = Queue.new
        threads = tool_calls.each_value.with_index.map do |tool_call, index|
          thread = Thread.new do
            Support::Instrumentation.with_workflow(workflow_context) do
              queue << capture_result(index, tool_call, caller_context, execute)
            end
          end
          thread.report_on_exception = false
          thread
        end

        collect_results(queue, threads.size, on_result:)
      ensure
        threads&.each(&:join)
      end

      def run_with_fibers(tool_calls, on_result:, &execute)
        begin
          require 'async'
          require 'async/queue'
        rescue LoadError
          raise LoadError, "The 'async' gem is required for concurrent tool execution with fibers. " \
                           "Add `gem 'async', '>= 2.0'` to your Gemfile or use `concurrency: :threads`."
        end
        if Gem.loaded_specs.fetch('async').version < Gem::Version.new('2.0')
          raise LoadError, "The 'async' gem version 2.0 or newer is required for concurrent tool execution with fibers."
        end

        caller_context = execution_context
        workflow_context = Support::Instrumentation.current_workflow
        # Inside a reactor, Sync runs the block in the calling fiber, so
        # results persist with the caller's execution state and connection.
        Sync do |task|
          isolated(caller_context) do
            queue = Async::Queue.new
            tasks = tool_calls.each_value.with_index.map do |tool_call, index|
              task.async do
                Support::Instrumentation.with_workflow(workflow_context) do
                  queue << capture_result(index, tool_call, caller_context, execute)
                end
              end
            end

            collect_results(queue, tasks.size, on_result:)
          ensure
            tasks&.each(&:wait)
          end
        end
      end

      def collect_results(queue, count, on_result:)
        results = Array.new(count)
        errors = []

        count.times do
          result = queue.pop
          if result.error
            errors << result.error
          else
            results[result.index] = [result.tool_call, result.value]
            on_result&.call(result.tool_call, result.value)
          end
        end

        raise errors.first if errors.any?

        results
      end

      def capture_result(index, tool_call, caller_context, execute)
        value = isolated(caller_context) { execute.call(tool_call) }
        Result.new(index:, tool_call:, value:)
      rescue Exception => e # rubocop:disable Lint/RescueException
        Result.new(index:, tool_call:, error: e)
      end

      # Rails gives a thread, and a fiber under fiber isolation, execution
      # state of its own: the block runs as its own unit of work, so its
      # connections return to the pool. A fiber sharing the caller's state
      # must not start one, whose completion resets the caller's Current
      # attributes.
      def isolated(caller_context, &)
        executor = rails_executor
        return yield unless executor && !execution_context.equal?(caller_context)

        executor.wrap(&)
      end

      def execution_context
        defined?(ActiveSupport::IsolatedExecutionState) ? ActiveSupport::IsolatedExecutionState.context : Thread.current
      end

      def rails_executor
        defined?(Rails) && Rails.respond_to?(:application) && Rails.application&.executor
      end

      private_class_method :run_with_threads, :run_with_fibers, :collect_results, :capture_result, :isolated,
                           :execution_context, :rails_executor
    end
  end
end

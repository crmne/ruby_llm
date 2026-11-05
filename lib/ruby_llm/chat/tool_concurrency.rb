# frozen_string_literal: true

module RubyLLM
  class Chat
    module ToolConcurrency # :nodoc: all
      MODES = %i[threads fibers].freeze
      Result = Struct.new(:index, :tool_call, :value, :error, keyword_init: true)

      module_function

      def run(mode, tool_calls, exclusive: nil, on_result: nil, &)
        rounds = rounds(tool_calls, exclusive)
        case mode
        when :threads
          run_with_threads(rounds, on_result:, &)
        when :fibers
          run_with_fibers(rounds, on_result:, &)
        end
      end

      # Groups the calls in the order the model gave them, so an exclusive
      # call waits for the calls before it and the calls after it wait for
      # it, as with a fair read-write lock.
      def rounds(tool_calls, exclusive)
        indexed = tool_calls.each_value.with_index.to_a
        return [indexed] unless exclusive

        indexed.chunk_while { |(first, _), (second, _)| !exclusive.call(first) && !exclusive.call(second) }.to_a
      end

      def run_with_threads(rounds, on_result:, &execute)
        caller_context = execution_context
        workflow_context = Support::Instrumentation.current_workflow
        instrumentation_context = Support::Instrumentation.capture_context
        results = Array.new(rounds.sum(&:size))
        rounds.each do |round|
          queue = Queue.new
          threads = []
          round.each do |tool_call, index|
            thread = Thread.new do
              result = capture_result(index, tool_call, caller_context, execute,
                                      workflow_context:, instrumentation_context:)
            ensure
              queue << (result || Result.new(index:, tool_call:, error: thread_exited_error(tool_call)))
            end
            thread.report_on_exception = false
            threads << thread
          end

          collect_results(queue, threads.size, results, on_result:)
        ensure
          threads&.each(&:join)
        end
        results
      end

      def run_with_fibers(rounds, on_result:, &execute)
        require_async
        caller_context = execution_context
        contexts = { workflow_context: Support::Instrumentation.current_workflow,
                     instrumentation_context: Support::Instrumentation.capture_context }
        results = Array.new(rounds.sum(&:size))
        # Inside a reactor, Sync runs the block in the calling fiber, so
        # results persist with the caller's execution state and connection.
        Sync do |task|
          isolated(caller_context) do
            rounds.each do |round|
              run_fiber_round(task, round, results, caller_context, contexts, on_result:, &execute)
            end
          end
        end
        results
      end

      def run_fiber_round(task, round, results, caller_context, contexts, on_result:, &execute)
        queue = Async::Queue.new
        tasks = []
        round.each do |tool_call, index|
          worker = task.async { queue << capture_result(index, tool_call, caller_context, execute, **contexts) }
          tasks << worker
        end

        collect_results(queue, tasks.size, results, on_result:)
      rescue Async::Stop
        tasks&.each(&:stop)
        raise
      ensure
        tasks&.each(&:wait)
      end

      def require_async
        begin
          require 'async'
          require 'async/queue'
        rescue LoadError
          raise LoadError, "The 'async' gem is required for concurrent tool execution with fibers. " \
                           "Add `gem 'async', '>= 2.0'` to your Gemfile or use `concurrency: :threads`."
        end
        return if Gem.loaded_specs.fetch('async').version >= Gem::Version.new('2.0')

        raise LoadError, "The 'async' gem version 2.0 or newer is required for concurrent tool execution with fibers."
      end

      def collect_results(queue, count, results, on_result:)
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
      end

      def capture_result(index, tool_call, caller_context, execute, workflow_context:, instrumentation_context:)
        value = nil
        Support::Instrumentation.with_workflow(workflow_context) do
          Support::Instrumentation.with_context(instrumentation_context) do
            value = isolated(caller_context) { execute.call(tool_call) }
          end
        end
        Result.new(index:, tool_call:, value:)
      rescue Exception => e # rubocop:disable Lint/RescueException
        Result.new(index:, tool_call:, error: e)
      end

      def thread_exited_error(tool_call)
        Error.new("Tool #{tool_call.name} exited its thread without a result")
      end

      # Rails gives a thread, and a fiber under fiber isolation, execution
      # state of its own: the block runs as its own unit of work, so its
      # connections return to the pool. A fiber sharing the caller's state
      # must not start one, whose completion resets the caller's Current
      # attributes. Unlike wrap, run! reports no errors: they reach the
      # caller, whose own executor reports what nothing rescues.
      def isolated(caller_context)
        executor = rails_executor
        return yield unless executor && !execution_context.equal?(caller_context)

        execution = executor.run!
        begin
          yield
        ensure
          execution.complete!
        end
      end

      def execution_context
        defined?(ActiveSupport::IsolatedExecutionState) ? ActiveSupport::IsolatedExecutionState.context : Thread.current
      end

      def rails_executor
        defined?(Rails) && Rails.respond_to?(:application) && Rails.application&.executor
      end

      private_class_method :rounds, :run_with_threads, :run_with_fibers, :run_fiber_round, :require_async,
                           :collect_results, :capture_result, :thread_exited_error, :isolated,
                           :execution_context, :rails_executor
    end
  end
end

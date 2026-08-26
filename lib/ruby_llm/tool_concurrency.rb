# frozen_string_literal: true

module RubyLLM
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
      executor = rails_executor
      workflow_context = Instrumentation.current_workflow
      queue = Queue.new
      threads = tool_calls.each_value.with_index.map do |tool_call, index|
        thread = Thread.new do
          Instrumentation.with_workflow(workflow_context) do
            queue << capture_result(index, tool_call, executor, execute)
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

      executor = rails_executor
      workflow_context = Instrumentation.current_workflow
      Async do |task|
        queue = Async::Queue.new
        tasks = tool_calls.each_value.with_index.map do |tool_call, index|
          task.async do
            Instrumentation.with_workflow(workflow_context) do
              queue << capture_result(index, tool_call, executor, execute)
            end
          end
        end

        collect_results(queue, tasks.size, on_result:)
      ensure
        tasks&.each(&:wait)
      end.wait
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

    def capture_result(index, tool_call, rails_executor, execute)
      tool_call, value = run_tool_call(tool_call, rails_executor, execute)
      Result.new(index:, tool_call:, value:)
    rescue Exception => e # rubocop:disable Lint/RescueException
      Result.new(index:, tool_call:, error: e)
    end

    def run_tool_call(tool_call, rails_executor, execute)
      if rails_executor
        rails_executor.wrap { [tool_call, execute.call(tool_call)] }
      else
        [tool_call, execute.call(tool_call)]
      end
    end

    def rails_executor
      defined?(Rails) && Rails.respond_to?(:application) && Rails.application&.executor
    end

    private_class_method :run_with_threads, :run_with_fibers, :collect_results, :capture_result, :run_tool_call,
                         :rails_executor
  end
end

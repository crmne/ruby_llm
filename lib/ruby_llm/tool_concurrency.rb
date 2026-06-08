# frozen_string_literal: true

module RubyLLM
  # Runs multiple tool calls concurrently with Ruby's built-in threads or optional fibers.
  module ToolConcurrency
    MODES = %i[threads fibers].freeze

    module_function

    def modes
      MODES
    end

    def supported?(name)
      MODES.include?(name)
    end

    def run(mode, tool_calls, &)
      case mode
      when :threads
        run_with_threads(tool_calls, &)
      when :fibers
        run_with_fibers(tool_calls, &)
      end
    end

    def run_with_threads(tool_calls, &execute)
      executor = rails_executor
      threads = tool_calls.map do |_, tool_call|
        thread = Thread.new { run_tool_call(tool_call, executor, execute) }
        thread.report_on_exception = false
        thread
      end

      threads.each(&:join)
      threads.map(&:value)
    end

    def run_with_fibers(tool_calls, &execute)
      begin
        require 'async'
      rescue LoadError
        raise LoadError, "The 'async' gem is required for concurrent tool execution with fibers. " \
                         "Add `gem 'async'` to your Gemfile or use `concurrency: :threads`."
      end

      executor = rails_executor
      Async do |task|
        tool_calls.map do |_, tool_call|
          task.async { run_tool_call(tool_call, executor, execute) }
        end.map(&:wait)
      end.wait
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

    private_class_method :run_with_threads, :run_with_fibers, :run_tool_call, :rails_executor
  end
end

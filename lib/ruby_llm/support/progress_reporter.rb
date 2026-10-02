# frozen_string_literal: true

module RubyLLM
  module Support
    # Carries the progress of work that runs inside a chat operation, such
    # as a tool call, to whoever listens for it. The chat installs a
    # listener for the current execution context; #report hands it a
    # Progress. Each concurrent tool call installs its own listener, so its
    # reports reach only its own callback. The listener lives in fiber
    # storage, which fibers and threads the tool starts inherit.
    module ProgressReporter # :nodoc:
      KEY = :ruby_llm_progress_listener

      module_function

      def listen(listener)
        previous = Fiber[KEY]
        Fiber[KEY] = listener
        yield
      ensure
        Fiber[KEY] = previous
      end

      def listener
        Fiber[KEY]
      end

      def report(progress)
        listener&.call(progress)
      end
    end
  end
end

# frozen_string_literal: true

module RubyLLM
  module Support
    # Carries the progress of work that runs inside a chat operation, such
    # as a tool call, to whoever listens for it. The chat installs a
    # listener for the current execution context; #report hands it a
    # Progress. Each concurrent tool call installs its own listener, so its
    # reports reach only its own callback. On Ruby 3.2 and later the
    # listener lives in fiber storage, which fibers and threads the tool
    # starts inherit.
    module ProgressReporter # :nodoc:
      KEY = :ruby_llm_progress_listener
      FIBER_STORAGE = Gem::Version.new(RUBY_VERSION) >= Gem::Version.new('3.2')

      module_function

      def listen(listener)
        previous = storage[KEY]
        storage[KEY] = listener
        yield
      ensure
        storage[KEY] = previous
      end

      def listener
        storage[KEY]
      end

      def report(progress)
        listener&.call(progress)
      end

      def storage
        FIBER_STORAGE ? Fiber : Thread.current
      end
    end
  end
end

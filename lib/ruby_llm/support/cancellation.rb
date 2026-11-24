# frozen_string_literal: true

module RubyLLM
  module Support
    # Lets work that runs inside a chat operation, such as a tool waiting on
    # a remote server, stop when the chat is cancelled. The chat installs a
    # checkpoint for the current fiber; #check raises CancelledError once
    # the chat has been cancelled.
    module Cancellation # :nodoc:
      KEY = :ruby_llm_cancellation_checkpoint
      CHECK_INTERVAL = 0.1

      module_function

      def watch(checkpoint)
        previous = Fiber[KEY]
        Fiber[KEY] = checkpoint
        yield
      ensure
        Fiber[KEY] = previous
      end

      # Watches +checkpoint+ along with the one around it until the block
      # returns, after which a thread that outlives it stops for neither.
      def nest(checkpoint, &)
        around = Fiber[KEY]
        active = true
        nested = lambda do
          next unless active

          around&.call
          checkpoint.call
        end
        watch(nested, &)
      ensure
        active = false
      end

      def check
        Fiber[KEY]&.call
      end

      def pause(seconds)
        deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + seconds
        loop do
          check
          remaining = deadline - Process.clock_gettime(Process::CLOCK_MONOTONIC)
          break unless remaining.positive?

          sleep [remaining, CHECK_INTERVAL].min
        end
      end
    end
  end
end

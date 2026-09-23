# frozen_string_literal: true

module RubyLLM
  module Support
    # Lets work that runs inside a chat operation, such as a tool waiting on
    # a remote server, stop when the chat is cancelled. The chat installs a
    # checkpoint for the current fiber; #check raises CancelledError once
    # the chat has been cancelled.
    module Cancellation # :nodoc:
      KEY = :ruby_llm_cancellation_checkpoint

      module_function

      def watch(checkpoint)
        previous = Thread.current[KEY]
        Thread.current[KEY] = checkpoint
        yield
      ensure
        Thread.current[KEY] = previous
      end

      def check
        Thread.current[KEY]&.call
      end
    end
  end
end

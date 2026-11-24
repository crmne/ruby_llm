# frozen_string_literal: true

module RubyLLM
  class MCP
    # Raised when a task failed or was cancelled. #to_h is the task as it
    # ended, which a chat saves with the tool call so its next run gives the
    # model the failure.
    class TaskError < Error # :nodoc:
      def initialize(message = nil, task:, **)
        @task = task
        super(message, **)
      end

      # Whether the tool call saved with +state+ waited on this task.
      def ends?(state)
        state&.dig('task', 'taskId') == @task.id
      end

      def to_h
        @task.to_h
      end
    end
  end
end

# frozen_string_literal: true

module RubyLLM
  class MCP
    # A tool call that an MCP server runs in the background, as the Tasks
    # extension describes. Declare MCP.extension :tasks, and a server may
    # answer a long call with a task instead of a result.
    #
    # A chat never waits for a task. It pauses the tool call, and
    # Chat#pending_tasks returns the tasks it waits on. #refresh checks on
    # a task once; Chat#complete checks on every one again and resumes the
    # chat once they are done:
    #
    #   task = chat.pending_tasks.first
    #   task.refresh
    #   task.status         # => :working
    #   task.status_message # => "Rendering page 3 of 12"
    #   task.poll_interval  # => 5.0
    #
    # MCP#call waits for the task of a tool you call directly.
    class Task
      include Support::Inspectable

      DONE = %i[completed failed cancelled].freeze
      private_constant :DONE

      # The task's id on its server.
      attr_reader :id

      # The ToolCall paused on the task, when it came from a chat.
      attr_reader :tool_call

      attr_reader :data, :answered # :nodoc:

      def self.load(mcp, state, tool_call: nil) # :nodoc:
        new(mcp, state['task'], answered: state['answered'], tool_call:)
      end

      def initialize(mcp, data, answered: nil, tool_call: nil) # :nodoc:
        @mcp = mcp
        @data = data
        @id = data['taskId']
        @answered = Array(answered)
        @tool_call = tool_call
      end

      # The task's state: +:working+, +:input_required+, +:completed+,
      # +:failed+, or +:cancelled+.
      def status
        data['status'].to_sym
      end

      # What the server says about the task's state, such as how far it
      # got, or +nil+.
      def status_message
        data['statusMessage']
      end

      # How many seconds the server asks you to wait before checking on the
      # task again, or +nil+.
      def poll_interval
        data['pollIntervalMs'] / 1000.0 if data['pollIntervalMs']
      end

      # When the server may forget the task, as a Time, or +nil+ when it
      # keeps the task for good.
      def expires_at
        Time.iso8601(data['createdAt']) + (data['ttlMs'] / 1000.0) if data['ttlMs'] && data['createdAt']
      end

      # Returns +true+ once the task completed, failed, or was cancelled.
      def done?
        DONE.include?(status)
      end

      # Returns +true+ when the task finished with a #result.
      def completed?
        status == :completed
      end

      # Returns +true+ when the task failed with an error.
      def failed?
        status == :failed
      end

      # Returns +true+ when the task was cancelled before it finished.
      def cancelled?
        status == :cancelled
      end

      # Returns the MCP::Result once the task #completed?, and +nil+ until
      # then. Raises MCP::Error when the task failed or was cancelled.
      def result
        raise error if failed? || cancelled?

        Result.new(data['result']) if completed?
      end

      # Checks on the task once and returns +self+, which now tells whether
      # the task is #done? and how soon to check again. Does nothing once
      # the task is #done?.
      def refresh
        @data = connected.poll_task(id) unless done?
        self
      end

      # Checks on the task until it is #done?, sleeping #poll_interval
      # seconds in between, and returns +self+. Answers the server's
      # requests for input with MCP.before_input_request callbacks.
      # +timeout+ defaults to the server's MCP.timeout, and the task is
      # cancelled when it runs out or the chat is cancelled.
      #
      # Raises MCP::Error when the task fails or the time runs out, and
      # MCP::InputRequiredError when no callback answers a request.
      def wait(timeout: nil, interval: nil)
        connected.await_task(self, timeout:, interval:)
      end

      # Asks the server to cancel the task, and returns +self+. The server
      # may still finish it, so check with #refresh.
      def cancel
        connected.cancel_task(id) unless done?
        self
      end

      def error # :nodoc:
        details = data['error'] || {}
        Error.new(details['message'] || status_message || "Task #{id} was #{status}",
                  code: details['code'], data: details['data'])
      end

      def record_answers(keys) # :nodoc:
        @answered |= keys
      end

      def to_h # :nodoc:
        { 'task' => data, 'answered' => (answered unless answered.empty?) }.compact
      end

      private

      def connected
        @mcp or raise ConfigurationError, "Connect the MCP that runs task #{id} with with_mcp to reach it"
      end

      def inspect_attributes
        { id:, status:, status_message: }
      end
    end
  end
end

# frozen_string_literal: true

module RubyLLM
  # A tool call that finishes later. Return one from Tool#execute and a
  # chat pauses the call instead of waiting for it, the way it pauses for
  # an approval. Chat#pending_tasks returns the tasks it waits on, and each
  # Chat#complete hands every one back to its tool's Tool#resume, which
  # returns the call's result once it has one:
  #
  #   class RunSubAgent < RubyLLM::Tool
  #     description "Hands a job to a sub-agent"
  #
  #     def execute(job:)
  #       run = SubAgentRun.start(job)
  #       run.finished? ? run.answer : RubyLLM::Task.new(status: :input_required, data: { "run_id" => run.id })
  #     end
  #
  #     def resume(task, **)
  #       run = SubAgentRun.find(task.data["run_id"]).continue
  #       run.finished? ? run.answer : task
  #     end
  #   end
  #
  # A task is saved with its tool call as #to_h, so a Rails chat can pause
  # in one process and resume in another. MCP::Task is the task of an MCP
  # tool call that a server runs in the background.
  class Task
    include Support::Inspectable

    DONE = %i[completed failed cancelled].freeze
    STATUSES = %i[working input_required].concat(DONE).freeze
    private_constant :DONE, :STATUSES

    # The task's state as a Symbol: +:working+, +:input_required+,
    # +:completed+, +:failed+, or +:cancelled+.
    attr_reader :status

    # What the task is doing, such as how far it got, or +nil+.
    attr_reader :status_message

    # How many seconds to wait before checking on the task again, or +nil+.
    attr_reader :poll_interval

    # The tool's own state for the task, a Hash with String keys that
    # serializes to JSON.
    attr_reader :data

    # The ToolCall paused on the task, when it came from a chat.
    attr_reader :tool_call

    # Returns the Task that +state+, the Hash #to_h returned, describes.
    def self.load(state, tool_call: nil)
      task = state.fetch('task')
      new(status: task.fetch('status'), status_message: task['status_message'],
          poll_interval: task['poll_interval'], data: task.fetch('data', {}), tool_call:)
    end

    # Returns a task with +status+, +:working+ unless the call waits on a
    # person, +:input_required+. +data+ is what Tool#resume needs to carry
    # the call on, as a Hash that serializes to JSON. Raises ArgumentError
    # for a status other than the five #status lists.
    def initialize(status: :working, status_message: nil, poll_interval: nil, data: {}, tool_call: nil)
      @status = status.to_sym
      raise ArgumentError, "Unknown task status: #{status.inspect}" unless STATUSES.include?(@status)

      @status_message = status_message
      @poll_interval = poll_interval
      @data = Support::Utils.deep_stringify_keys(Support::Utils.deep_dup(data))
      @tool_call = tool_call
    end

    # Returns +true+ when the task waits on a person, so checking on it
    # changes nothing until they act.
    def input_required?
      status == :input_required
    end

    # Returns +true+ once the task completed, failed, or was cancelled.
    def done?
      DONE.include?(status)
    end

    # Returns +true+ when the task finished with a result.
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

    # Checks on the task once and returns +self+. Subclasses that can check
    # on their work override it; the base implementation does nothing.
    def refresh
      self
    end

    # Stops the task and returns +self+. A chat calls it when it is
    # cancelled while the call waits. Subclasses that can stop their work
    # override it; the base implementation does nothing.
    def cancel
      self
    end

    # Returns the task as a Hash that serializes to JSON, which ::load turns
    # back into the task.
    def to_h
      task = { 'status' => status.to_s, 'status_message' => status_message,
               'poll_interval' => poll_interval, 'data' => (data unless data.empty?) }
      { 'task' => task.compact }
    end

    private

    def inspect_attributes
      { status:, status_message: }
    end
  end
end

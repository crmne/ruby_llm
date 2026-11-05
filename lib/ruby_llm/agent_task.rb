# frozen_string_literal: true

module RubyLLM
  # The Task a subagent's call pauses on while the agent waits (see
  # AgentTool). It is Task#input_required? when the agent needs a person,
  # and #agent is the agent, so you can settle what it waits for:
  #
  #   task = chat.pending_tasks.first
  #   task.agent.pending_approvals.each { |call| task.agent.approve(call) }
  #   chat.complete
  #
  # The agent lives in the process that ran it. A task loaded in another
  # process has no #agent, and resuming it reports that the work was lost.
  class AgentTask < Task
    # The Agent the call waits on, or +nil+ in another process.
    attr_reader :agent

    # Returns the AgentTask that +state+ describes, for +agent+.
    def self.load(state, tool_call: nil, agent: nil) # :nodoc:
      task = state.fetch('task')
      new(status: task.fetch('status'), status_message: task['status_message'], data: task.fetch('data', {}),
          tool_call:, agent:)
    end

    def initialize(agent: nil, **) # :nodoc:
      super(**)
      @agent = agent
    end
  end
end

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
  # An agent that sets Agent::chat_class waits in its chat record, so a
  # task loaded in any process finds it, and #agent is that record, as
  # Agent::find returns it. A persisted chat lists the approvals its
  # subagents wait for in its own +pending_approvals+, and settles them
  # with its own +approve+ and +deny+.
  #
  # Any other agent lives in the process that ran it. A task loaded in
  # another process has no #agent, and resuming it reports that the work
  # was lost.
  class AgentTask < Task
    # Returns the AgentTask that +state+ describes, for +agent+.
    def self.load(state, tool_call: nil, agent: nil, tool: nil) # :nodoc:
      task = state.fetch('task')
      new(status: task.fetch('status'), status_message: task['status_message'], data: task.fetch('data', {}),
          tool_call:, agent:, tool:)
    end

    def initialize(agent: nil, tool: nil, **) # :nodoc:
      super(**)
      @agent = agent
      @tool = tool
    end

    # Returns the agent the call waits on: an Agent, or the chat record of
    # an agent that sets Agent::chat_class. Returns +nil+ in another process
    # for an agent without one, and for a chat record that no longer exists.
    def agent
      @agent ||= @tool&.agent_for(self)
    end

    # Cancels the agent, as Chat#cancel does for the chat that waits on it,
    # along with the tasks the agent waits on, and returns +self+.
    def cancel
      stop(agent) if agent
      @tool&.forget(data['run'])
      self
    end

    private

    def stop(agent)
      agent.cancel
      agent.run_tools
    rescue CancelledError
      nil
    end
  end
end

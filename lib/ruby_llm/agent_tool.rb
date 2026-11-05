# frozen_string_literal: true

require 'securerandom'

module RubyLLM
  # The Tool an Agent class becomes when it goes wherever tools go, so a
  # model can hand work to it: a subagent. Agent::to_tool returns one, and
  # Chat#with_tools and Agent::tools convert an Agent class themselves.
  #
  #   class ResearchAgent < RubyLLM::Agent
  #     description "Researches a question across the web and reports back"
  #     tools WebSearch, ReadPage
  #   end
  #
  #   chat.with_tools(ResearchAgent).ask "What changed in Ruby 4.0?"
  #
  # The tool is named after the agent (+research_agent+, or
  # +billing_research_agent+ for <tt>Billing::ResearchAgent</tt>) and takes
  # a +task+, everything the agent needs written to stand alone, plus the
  # agent's ::inputs that ::to_tool was not given. Each call runs a fresh
  # instance of the agent on the task, under the owner of the chat that
  # called it, and returns the content of its last answer. When the agent
  # waits, for an approval, a question, or a task of its own, the call
  # pauses on an AgentTask instead, and Chat#complete carries the agent on
  # once nothing holds it.
  class AgentTool < Tool
    class << self
      # The Agent class this tool runs.
      attr_reader :agent_class

      # The agent's ::inputs that the model supplies, as parameters.
      attr_reader :input_parameters # :nodoc:

      # Returns a Tool class for +agent_class+, with the inputs in +given+
      # left out of its parameters.
      def for(agent_class, given) # :nodoc:
        raise ArgumentError, 'An agent needs a class name to become a tool' unless agent_class.name
        if agent_class.inputs.include?(:task)
          raise ArgumentError, "#{agent_class.name} has an input named task, which its tool takes for the prompt"
        end

        missing = agent_class.inputs - given.keys.map(&:to_sym)
        Class.new(self) do
          @agent_class = agent_class
          @input_parameters = missing
          description(agent_class.description || "Hands a task to the #{agent_class.name} agent, which reports back.")
          parameter :task, description: 'Everything the agent needs to do the work, written to stand alone'
          missing.each { |input| parameter input, description: "The agent's #{input}" }
        end
      end

      # Returns the agent's name in snake case, such as +research_agent+.
      def tool_name
        Support::Utils.underscore(agent_class.name.gsub('::', '_'))
      end
    end

    def initialize(inputs = {}) # :nodoc:
      super()
      @inputs = inputs
      @agents = {}
      @lock = Mutex.new
    end

    # Runs a fresh instance of the agent on +task+, with the inputs given to
    # Agent::to_tool and those the model chose, and returns the content of
    # its last answer, or an AgentTask when the agent waits.
    def execute(task:, tool_call: nil, **inputs)
      agent = self.class.agent_class.new(**@inputs, **inputs.slice(*self.class.input_parameters))
      owner = Accounting::Usage.owner
      agent.with_owner(owner) unless owner.nil?
      run = SecureRandom.uuid
      @lock.synchronize { @agents[run] = agent }
      running(run) { report(agent, agent.ask(task), run, tool_call) }
    end

    # Carries the agent on once nothing holds it, with Chat#complete, and
    # returns its answer, or +task+ again while it still waits.
    def resume(task, **)
      agent = task.agent
      return { error: "This agent's work was lost. Start it again with everything it needs." } unless agent
      return task if agent.awaiting_person?

      run = task.data['run']
      running(run) { report(agent, agent.complete, run, task.tool_call) }
    end

    # Returns the AgentTask the call paused on, with the agent it waits for.
    def task(state, tool_call: nil)
      run = state.dig('task', 'data', 'run')
      AgentTask.load(state, tool_call:, tool: self, agent: @lock.synchronize { @agents[run] })
    end

    # Lets go of the agent of +run+, once its call is over.
    def forget(run) # :nodoc:
      @lock.synchronize { @agents.delete(run) }
    end

    private

    def running(run)
      yield
    rescue StandardError
      forget(run)
      raise
    end

    def report(agent, message, run, tool_call)
      if agent.waiting?
        status = agent.awaiting_person? ? :input_required : :working
        return AgentTask.new(status:, agent:, tool: self, tool_call:,
                             data: { 'agent' => self.class.agent_class.name, 'run' => run })
      end

      forget(run)
      message&.content
    end
  end
end

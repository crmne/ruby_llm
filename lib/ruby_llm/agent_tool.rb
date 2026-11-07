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
  #
  # An agent that sets Agent::chat_class runs each call in a new record of
  # that class, made with Agent::create!, so any process can carry it on.
  # See AgentTask.
  class AgentTool < Tool
    class << self
      # The Agent class this tool runs.
      attr_reader :agent_class

      # The agent's ::inputs that the model supplies, as parameters.
      attr_reader :input_parameters # :nodoc:

      # Finds and links the chat records that subagents run in, for an
      # application that stores them, such as the Rails integration.
      attr_accessor :store # :nodoc:

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
    # its last answer, or an AgentTask when the agent waits. An agent that
    # sets Agent::chat_class carries on the record that a process which died
    # left for this call, instead of starting another.
    def execute(task:, tool_call: nil, **inputs)
      inputs = run_inputs(inputs)
      return carry_on(self.class.agent_class.new(**inputs), tool_call) { |agent| agent.ask(task) } unless records?

      agent = linked_agent(tool_call, inputs) || start(task, tool_call, inputs)
      carry_on(agent, tool_call, &:complete)
    end

    # Carries the agent on once nothing holds it, with Chat#complete, and
    # returns its answer, or an AgentTask again while it still waits.
    def resume(task, **)
      agent = task.agent
      return { error: "This agent's work was lost. Start it again with everything it needs." } unless agent
      return report(agent, nil, task.data['run'], task.tool_call) if agent.awaiting_person?

      carry_on(agent, task.tool_call, run: task.data['run'], &:complete)
    end

    # Returns the AgentTask the call paused on, which finds the agent it
    # waits for when asked (see AgentTask#agent).
    def task(state, tool_call: nil)
      AgentTask.load(state, tool_call:, tool: self)
    end

    # Returns the agent +task+ waits for: the one this process ran, or the
    # record of an agent that sets Agent::chat_class, or +nil+.
    def agent_for(task) # :nodoc:
      agent = @lock.synchronize { @agents[task.data['run']] }
      return agent if agent || !records?

      linked_agent(task.tool_call, run_inputs(task.tool_call&.arguments || {}))
    end

    # Lets go of the agent of +run+, once its call is over.
    def forget(run) # :nodoc:
      @lock.synchronize { @agents.delete(run) }
    end

    private

    def records?
      !self.class.agent_class.chat_class.nil?
    end

    def run_inputs(chosen)
      @inputs.merge(chosen.transform_keys(&:to_sym).slice(*self.class.input_parameters))
    end

    def start(task, tool_call, inputs)
      self.class.agent_class.create!(**inputs).tap do |chat|
        chat.ask_later(task)
        AgentTool.store&.link_subagent_chat(tool_call, chat) if tool_call
      end
    end

    def linked_agent(tool_call, inputs)
      chat = AgentTool.store&.subagent_chat(tool_call) if tool_call
      self.class.agent_class.new(chat:, persist_instructions: false, **inputs).chat if chat
    end

    def carry_on(agent, tool_call, run: SecureRandom.uuid)
      owner = Accounting::Usage.owner
      agent.with_owner(owner) unless owner.nil?
      @lock.synchronize { @agents[run] = agent }
      running(run) { report(agent, yield(agent), run, tool_call) }
    end

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

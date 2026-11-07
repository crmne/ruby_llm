# frozen_string_literal: true

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
  # called it, and returns the content of its last answer.
  #
  # The agent lives only as long as its call, so it has to finish within
  # it. When it stops to wait instead, for an approval, a question, or a
  # task, the call raises ConfigurationError. To let a subagent wait for a
  # person, give it a chat of its own, as the Agents guide shows.
  class AgentTool < Tool
    GUIDE = 'https://rubyllm.com/agents/#subagents-that-wait-for-a-person'
    private_constant :GUIDE

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
    end

    # Runs a fresh instance of the agent on +task+, with the inputs given to
    # Agent::to_tool and those the model chose, and returns the content of
    # its last answer. Raises ConfigurationError, naming what the agent
    # waits for, when it stops to wait instead of answering.
    def execute(task:, **inputs)
      agent = self.class.agent_class.new(**@inputs, **inputs.slice(*self.class.input_parameters))
      owner = Accounting::Usage.owner
      agent.with_owner(owner) unless owner.nil?
      message = agent.ask(task)
      raise ConfigurationError, stopped(agent) if agent.waiting?

      message&.content
    end

    private

    def stopped(agent)
      people = agent.pending_questions.map do |question|
        "a person to #{question.approval? ? 'approve' : 'answer'} #{question.tool_call.name}"
      end
      tasks = agent.pending_tasks.map { |task| "the task of #{task.tool_call.name}" }
      "#{self.class.agent_class.name} stopped to wait for #{(people + tasks).join(' and ')}, but an agent used " \
        "as a tool has to finish within its call. To let it wait, give it a chat of its own: #{GUIDE}"
    end
  end
end

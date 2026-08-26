# frozen_string_literal: true

module RubyLLM
  # Groups named coworkers and creates tools for delegating work.
  #
  #   team = RubyLLM::Team.new
  #   team.add(:researcher, ResearcherAgent)
  #   chat.with_tools(*team.collaboration_tools)
  #
  # Registered classes are instantiated per call; registered instances are reused.
  class Team
    def initialize
      @agents = {}
    end

    # Registers +agent+ under +role+ and returns +self+.
    def add(role, agent)
      role = role.to_s
      raise ArgumentError, 'provide a role' if role.empty?
      raise ArgumentError, 'provide an agent' unless agent

      @agents[role] = agent
      self
    end

    # Returns collaboration tools for the current registry snapshot.
    def collaboration_tools
      agents = @agents.dup.freeze
      [DelegateWork.new(agents), AskQuestion.new(agents)]
    end

    class CoworkerTool < Tool # :nodoc:
      parameter :coworker, type: 'string', description: 'Name of the teammate to consult'
      parameter :context, type: 'string', description: 'Shared context for the teammate',
                          required: false

      def initialize(agents)
        super()
        @agents = agents
      end

      def description
        "#{self.class.description}\n\nCoworkers: #{coworkers}"
      end

      private

      def with_context(main, context)
        context ? "#{main}\n\nContext: #{context}" : main
      end

      def consult(prompt:, coworker:)
        agent = @agents[coworker.to_s]
        return unknown_coworker(coworker) unless agent

        begin
          agent = agent.new if agent.is_a?(Class)
          content, attachments = extract_result(agent.ask(prompt))
        rescue StandardError => e
          return { error: "Coworker '#{coworker}' failed: #{e.message}" }
        end

        attachments.empty? ? content : [content, *attachments]
      end

      def unknown_coworker(coworker)
        { error: "Unknown coworker '#{coworker}'. Available: #{coworkers}" }
      end

      def coworkers
        @agents.keys.join(', ')
      end

      def extract_result(result)
        return [result, []] unless result.respond_to?(:content)

        attachments = result.respond_to?(:attachments) ? Array(result.attachments) : []
        [result.content, attachments]
      end
    end

    class DelegateWork < CoworkerTool # :nodoc:
      description 'Delegate a task to a teammate and get their result'
      parameter :task, type: 'string', description: 'The task to delegate'

      def self.tool_name = 'delegate_work'

      def execute(task:, coworker:, context: nil)
        consult(prompt: with_context(task, context), coworker: coworker)
      end
    end

    class AskQuestion < CoworkerTool # :nodoc:
      description 'Ask a teammate a question about their expertise'
      parameter :question, type: 'string', description: 'The question to ask'

      def self.tool_name = 'ask_question'

      def execute(question:, coworker:, context: nil)
        consult(prompt: with_context(question, context), coworker: coworker)
      end
    end

    private_constant :CoworkerTool, :DelegateWork, :AskQuestion
  end
end

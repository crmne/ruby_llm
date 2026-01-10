# frozen_string_literal: true

module RubyLLM
  module AgentSDK
    # Configuration for a subagent defined programmatically
    #
    # Subagents are separate agent instances that your main agent can spawn
    # to handle focused subtasks. Use subagents to isolate context, run
    # multiple analyses in parallel, and apply specialized instructions.
    #
    # @example Define a code reviewer subagent
    #   AgentDefinition.new(
    #     description: 'Expert code review specialist',
    #     prompt: 'You are a code review specialist. Focus on security and best practices.',
    #     tools: %w[Read Glob Grep],
    #     model: :sonnet
    #   )
    #
    class AgentDefinition
      # @return [String] Natural language description of when to use this agent
      attr_accessor :description

      # @return [String] The agent's system prompt defining its role and behavior
      attr_accessor :prompt

      # @return [Array<String>, nil] Allowed tool names. If nil, inherits all tools
      attr_accessor :tools

      # @return [Symbol, nil] Model override (:sonnet, :opus, :haiku, :inherit, nil)
      attr_accessor :model

      def initialize(description:, prompt:, tools: nil, model: nil)
        @description = description
        @prompt = prompt
        @tools = tools
        @model = model
      end

      # Check if tools are inherited from parent
      #
      # @return [Boolean]
      def inherits_tools?
        tools.nil?
      end

      # Get the effective model setting
      #
      # @return [Symbol, nil]
      def effective_model
        return nil if model.nil? || model == :inherit

        model
      end

      # Convert to hash for serialization
      #
      # @return [Hash]
      def to_h
        {
          description: description,
          prompt: prompt,
          tools: tools,
          model: model
        }.compact
      end

      # Create from hash
      #
      # @param hash [Hash] Agent definition attributes
      # @return [AgentDefinition]
      def self.from_h(hash)
        new(
          description: hash[:description] || hash['description'],
          prompt: hash[:prompt] || hash['prompt'],
          tools: hash[:tools] || hash['tools'],
          model: hash[:model] || hash['model']
        )
      end
    end
  end
end

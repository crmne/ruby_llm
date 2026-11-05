# frozen_string_literal: true

module RubyLLM
  class Agent
    # The Agent::description and Agent::to_tool macros, which let an agent
    # class go wherever tools go, as an AgentTool.
    module ToolConversion # :nodoc:
      def description(text = nil)
        return @description unless text

        @description = text
      end

      def to_tool(**inputs)
        AgentTool.for(self, inputs).new(inputs)
      end
    end
  end
end

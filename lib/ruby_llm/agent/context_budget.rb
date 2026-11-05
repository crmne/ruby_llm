# frozen_string_literal: true

module RubyLLM
  class Agent
    # Applies the Agent::context_budget macro to every chat an agent builds
    # or finds.
    module ContextBudget # :nodoc:
      def apply_configuration(chat, **)
        super.tap { chat.with_context_budget(@context_budget) if @context_budget }
      end
    end
  end
end

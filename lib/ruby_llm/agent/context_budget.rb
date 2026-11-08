# frozen_string_literal: true

module RubyLLM
  class Agent
    # Applies the Agent::context_budget macro to every chat an agent builds
    # or finds.
    module ContextBudget # :nodoc:
      def apply_configuration(chat, input_values:, **)
        super.tap do
          next if @context_budget.nil?

          chat.with_context_budget(evaluate(@context_budget, runtime_context(chat:, inputs: input_values)) || nil)
        end
      end

      private

      def context_budget_option(budget, **shares, &block)
        return Chat::ContextBudget.normalize(budget, **shares) || false unless block
        raise ArgumentError, 'context_budget takes options or a block, not both' if shares.any? || budget != {}

        block
      end
    end
  end
end

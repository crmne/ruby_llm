# frozen_string_literal: true

module RubyLLM
  class Agent
    # Applies the Agent::owner macro's owner to every chat an agent builds
    # or finds, with Chat#with_owner, and hands it to subclasses.
    module Ownership # :nodoc:
      def inherited(subclass)
        super
        subclass.instance_variable_set(:@owner, @owner)
      end

      def apply_configuration(chat, input_values:, **)
        super.tap do
          value = evaluate(owner, runtime_context(chat:, inputs: input_values))
          chat.with_owner(value) unless value.nil?
        end
      end
    end
  end
end

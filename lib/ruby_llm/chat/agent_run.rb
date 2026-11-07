# frozen_string_literal: true

module RubyLLM
  class Chat
    # Wraps a run of a chat an Agent configured in one +agent.ruby_llm+
    # event, whether it is reached through the chat, the agent, or a
    # persisted record. Only the outermost operation of a run opens one, so
    # #ask, #complete, and the moves they make report a single event.
    module AgentRun # :nodoc:
      OPERATIONS = %i[complete generate run_tools step].freeze

      OPERATIONS.each do |operation|
        define_method(operation) do |*args, **kwargs, &block|
          chat = agent_run_chat
          return super(*args, **kwargs, &block) unless chat

          chat.running_agent { super(*args, **kwargs, &block) }
        end
      end
    end
  end
end

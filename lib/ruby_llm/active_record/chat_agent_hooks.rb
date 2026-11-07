# frozen_string_literal: true

module RubyLLM
  module ActiveRecord
    # What the Agent that configured a persisted chat adds to its
    # operations: its rescue_from handlers, and one +agent.ruby_llm+ event
    # around each run, shared with the chat the record wraps.
    module ChatAgentHooks # :nodoc:
      include RubyLLM::Chat::AgentRun
      include RubyLLM::Chat::Rescuable

      private

      def agent_run_chat = @chat
    end
  end
end

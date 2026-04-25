# frozen_string_literal: true

module RubyLLM
  module Providers
    class DeepSeek
      # Chat methods of the DeepSeek API integration
      module Chat
        module_function

        def format_role(role)
          role.to_s
        end

        # `deepseek-reasoner` rejects multi-turn requests where any prior
        # assistant message is missing `reasoning_content`, with:
        #   "The `reasoning_content` in the thinking mode must be passed
        #    back to the API."
        # The OpenAI default omits the key when no thinking text was
        # captured (e.g. a short turn that only emitted tool calls), so
        # always emit it here — empty string when absent.
        def format_thinking(msg)
          return {} unless msg.role == :assistant

          thinking = msg.thinking
          text = thinking&.text.to_s
          payload = { reasoning_content: text }
          payload[:reasoning] = text unless text.empty?
          payload[:reasoning_signature] = thinking.signature if thinking&.signature
          payload
        end
      end
    end
  end
end

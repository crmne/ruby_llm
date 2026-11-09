# frozen_string_literal: true

module RubyLLM
  module Providers
    class Mistral
      # Counts a request through Mistral's Responses input-token endpoint,
      # the only token counting route Mistral offers, whichever protocol the
      # chat itself runs on.
      class InputTokens < Protocols::Responses
        include Protocols::Responses::TokenCounting

        def render_count_tokens_payload(messages, **)
          payload = super(messages.flat_map { |message| countable_messages(message) }, **)
          payload.merge(input: payload[:input].map { |item| typed_item(item) })
        end

        private

        # Mistral rejects an input item that doesn't name its type.
        def typed_item(item)
          item.key?(:role) ? { type: 'message' }.merge(item) : item
        end

        # Native content from other protocols doesn't fit Responses input,
        # and the endpoint can't take unsigned thinking, so thinking goes in
        # as text to keep it in the count.
        def countable_messages(message)
          plain = message.without_native_content
          text = message.thinking&.text
          text ? [Message.new(role: :assistant, content: text), plain] : [plain]
        end
      end
    end
  end
end

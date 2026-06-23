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

        def format_thinking(msg)
          return {} unless msg.role == :assistant

          thinking = msg.thinking
          text = thinking&.text.to_s
          payload = { reasoning_content: text }
          payload[:reasoning] = text unless text.empty?
          payload[:reasoning_signature] = thinking.signature if thinking&.signature
          payload
        end

        def format_content(content)
          Protocols::ChatCompletions::Media.format_content(
            content,
            document_attachments: :none,
            image_attachments: false,
            audio_attachments: false
          )
        end
      end
    end
  end
end

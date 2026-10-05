# frozen_string_literal: true

module RubyLLM
  module Providers
    class XAI
      # Chat implementation for xAI
      # https://docs.x.ai/docs/api-reference#chat-completions
      module Chat
        def format_role(role)
          role.to_s
        end

        def supported_attachment?(attachment)
          Protocols::ChatCompletions::Media.supported_attachment?(
            attachment, document_attachments: :none, audio_attachments: false
          )
        end

        def format_content(content, attachments = [])
          Protocols::ChatCompletions::Media.format_content(
            content,
            attachments,
            document_attachments: :none,
            image_attachments: true,
            audio_attachments: false
          )
        end
      end
    end
  end
end

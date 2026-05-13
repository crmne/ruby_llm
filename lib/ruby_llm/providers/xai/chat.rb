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

        def format_content(content)
          OpenAI::Media.format_content(
            content,
            document_attachments: :none,
            image_attachments: true,
            audio_attachments: false
          )
        end
      end
    end
  end
end

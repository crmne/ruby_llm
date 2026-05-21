# frozen_string_literal: true

module RubyLLM
  module Providers
    class Astraflow
      # Chat implementation for Astraflow.
      # Astraflow is fully OpenAI-compatible, so we delegate to OpenAI::Media.
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

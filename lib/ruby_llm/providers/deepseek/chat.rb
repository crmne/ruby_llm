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

# frozen_string_literal: true

module RubyLLM
  module Providers
    class Ollama
      # Chat methods of the Ollama API integration
      module Chat
        module_function

        def format_content(content, attachments = [])
          Ollama::Media.format_content(content, attachments)
        end

        def format_role(role)
          role.to_s
        end
      end
    end
  end
end

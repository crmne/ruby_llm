# frozen_string_literal: true

module RubyLLM
  module Providers
    class Ollama
      # Chat methods of the Ollama API integration
      module Chat
        module_function

        def render_payload(messages, tools:, temperature:, model:, stream: false, max_output_tokens: nil,
                           schema: nil, thinking: nil, citations: false, caching: nil, tool_prefs: nil)
          if thinking&.budget
            RubyLLM.logger.debug { "Ollama has no thinking budgets; ignoring budget #{thinking.budget}" }
          end
          super
        end

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

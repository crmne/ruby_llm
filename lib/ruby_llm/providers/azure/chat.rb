# frozen_string_literal: true

module RubyLLM
  module Providers
    class Azure
      # Chat methods of the Azure AI Foundry API integration
      module Chat
        def completion_url
          azure_endpoint(:chat)
        end

        def supported_attachment?(attachment)
          Azure::Media.supported_attachment?(attachment)
        end

        def render_content(content, attachments = [])
          Media.render_content(content, attachments)
        end

        def render_role(role)
          role.to_s
        end

        private

        # Grok on Azure reports cached tokens beside prompt_tokens, not inside
        # them, so prompt_tokens is the uncached input.
        def input_tokens(usage)
          grok? ? usage['prompt_tokens'] : super
        end

        def grok?
          return false unless @model

          @model.family == 'grok' || @model.id.start_with?('grok')
        end
      end
    end
  end
end

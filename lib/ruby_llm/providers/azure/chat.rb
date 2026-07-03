# frozen_string_literal: true

module RubyLLM
  module Providers
    class Azure
      # Chat methods of the Azure AI Foundry API integration
      module Chat
        def completion_url
          azure_endpoint(:chat)
        end

        def format_content(content)
          Media.format_content(content)
        end

        def format_role(role)
          role.to_s
        end
      end
    end
  end
end

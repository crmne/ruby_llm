# frozen_string_literal: true

module RubyLLM
  module Providers
    class Azure < Provider
      # Azure's dialect of the OpenAI Responses API, served from the
      # implicitly versioned openai/v1 base. The model field carries the
      # deployment name, as on Chat Completions. Azure offers no web_search
      # server tool and rejects the user_data file upload purpose.
      class Responses < Protocols::Responses
        SERVER_TOOL_ALIASES = Protocols::Responses::SERVER_TOOL_ALIASES.except(:web_search).freeze

        def completion_url
          "#{@provider.azure_openai_v1_base}/responses"
        end

        def server_tool_aliases
          SERVER_TOOL_ALIASES
        end

        def provider_file_upload_options(_attachment)
          { purpose: 'assistants' }
        end
      end
    end
  end
end

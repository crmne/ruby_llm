# frozen_string_literal: true

module RubyLLM
  module Providers
    class Bedrock
      module Mantle
        # The OpenAI Responses API on the bedrock-mantle endpoint, which
        # serves every non-Claude model mantle hosts: OpenAI, Qwen, Mistral,
        # DeepSeek, and the rest.
        class Responses < Protocols::Responses
          include Mantle

          # AWS Web Search fetches pages as part of the web_search tool, with
          # no separate fetch tool to enable.
          SERVER_TOOL_ALIASES = Protocols::Responses::SERVER_TOOL_ALIASES.merge(
            web_fetch: { tool: { type: 'web_search' } }
          ).freeze

          def server_tool_aliases
            SERVER_TOOL_ALIASES
          end

          def completion_url
            "#{openai_api_path}/responses"
          end

          def provider_file_references?
            false
          end
        end
      end
    end
  end
end

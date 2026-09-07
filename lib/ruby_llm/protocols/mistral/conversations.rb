# frozen_string_literal: true

module RubyLLM
  module Protocols
    module Mistral
      # Mistral's Conversations API, including provider-executed tools.
      class Conversations < ChatCompletions
        include Mistral::Content
        include Conversations::Chat
        include Conversations::Streaming
        include Conversations::Images

        public :render

        SERVER_TOOL_ALIASES = {
          web_search: { tool: { type: 'web_search' } },
          web_fetch: { tool: { type: 'web_search' } },
          code_execution: { tool: { type: 'code_interpreter' } },
          file_search: { tool: { type: 'document_library' } },
          image_generation: { tool: { type: 'image_generation' } },
          mcp: { tool: { type: 'connector' } }
        }.freeze

        def server_tool_aliases
          SERVER_TOOL_ALIASES
        end
      end
    end
  end
end

# frozen_string_literal: true

module RubyLLM
  module Protocols
    # The Gemini Interactions API for conversations and hosted tools.
    class Interactions < Protocol
      include Interactions::Chat
      include Interactions::Content
      include Interactions::Tools
      include Interactions::Streaming
      include Interactions::Transcription

      public :render

      SERVER_TOOL_ALIASES = {
        mcp: { tool: { type: 'mcp_server' } },
        web_search: { tool: { type: 'google_search' } },
        web_fetch: { tool: { type: 'url_context' } },
        code_execution: { tool: { type: 'code_execution' } },
        file_search: { tool: { type: 'file_search' } },
        google_maps: { tool: { type: 'google_maps' } }
      }.freeze

      def server_tool_aliases
        SERVER_TOOL_ALIASES
      end
    end
  end
end

# frozen_string_literal: true

module RubyLLM
  module Protocols
    # The Google Gemini generateContent API.
    class Gemini < Protocol
      include Gemini::Caches
      include Gemini::Chat
      include Gemini::Embeddings
      include Gemini::Images
      include Gemini::Videos
      include Gemini::Media
      include Gemini::Models
      include Gemini::Streaming
      include Gemini::Tools
      include Gemini::Speech
      include Gemini::Transcription

      # Gemini nests each tool's options inside its key, so aliases are
      # lambdas placing the options there.
      SERVER_TOOL_ALIASES = %i[
        google_search url_context code_execution file_search google_maps
      ].to_h do |tool_key|
        [tool_key, ->(options) { { tool: { tool_key => Utils.deep_symbolize_keys(options) } } }]
      end.merge(
        web_search: ->(options) { { tool: { google_search: Utils.deep_symbolize_keys(options) } } },
        web_fetch: ->(options) { { tool: { url_context: Utils.deep_symbolize_keys(options) } } }
      ).freeze

      def server_tool_aliases
        SERVER_TOOL_ALIASES
      end
    end
  end
end

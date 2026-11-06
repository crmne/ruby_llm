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
      include Gemini::RequestShapes
      include Gemini::Streaming
      include Gemini::Tools
      include Gemini::Speech
      include Gemini::Transcription
      include Gemini::LongDecode

      # Gemini nests each tool's options inside its key, so aliases are
      # lambdas placing the options there.
      SERVER_TOOL_ALIASES = %i[
        google_search url_context code_execution file_search google_maps
      ].to_h do |tool_key|
        [tool_key, ->(options) { { tool: { tool_key => Support::Utils.deep_symbolize_keys(options) } } }]
      end.merge(
        web_search: ->(options) { { tool: { google_search: Support::Utils.deep_symbolize_keys(options) } } },
        web_fetch: ->(options) { { tool: { url_context: Support::Utils.deep_symbolize_keys(options) } } }
      ).freeze

      # Returns the pages the message's searches used, as WebSource objects.
      def self.parse_web_sources(message)
        searches = message.server_tool_calls.select { |call| call.type == 'google_search' }
        searches.flat_map { |call| Array(call.result) }.map do |chunk|
          WebSource.new(url: chunk.dig('web', 'uri'), title: chunk.dig('web', 'title'))
        end
      end

      def server_tool_aliases
        SERVER_TOOL_ALIASES
      end
    end
  end
end

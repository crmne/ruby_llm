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

      # Search results arrive as Google's redirect links. A page the model
      # chose to read through url_context arrives in the same list under its
      # own address, and need not be a result.
      SEARCH_RESULT_LINK = 'https://vertexaisearch.cloud.google.com/grounding-api-redirect/'

      # Returns the pages the message's searches returned, as WebSource objects.
      def self.parse_web_sources(message)
        searches = message.server_tool_calls.select { |call| call.type == 'google_search' }
        pages = searches.flat_map { |call| Array(call.result) }.map { |chunk| chunk['web'] }
        pages.select { |page| page['uri'].start_with?(SEARCH_RESULT_LINK) }.map do |page|
          WebSource.new(url: page['uri'], title: page['title'])
        end
      end

      def server_tool_aliases
        SERVER_TOOL_ALIASES
      end
    end
  end
end

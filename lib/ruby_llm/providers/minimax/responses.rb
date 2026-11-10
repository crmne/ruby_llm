# frozen_string_literal: true

module RubyLLM
  module Providers
    class MiniMax
      # MiniMax's Responses route, used for web search because only this
      # endpoint returns citations. It holds no state: store is always false.
      # https://platform.minimax.io/docs/api-reference/responses-create
      class Responses < Protocols::Responses
        SERVER_TOOL_ALIASES = {
          web_search: { tool: { type: 'web_search' } }
        }.freeze

        # MiniMax reports a search's pages only through its citations.
        def self.parse_web_sources(message)
          message.citations.filter_map do |citation|
            WebSource.new(url: citation.url, title: citation.title) if citation.url
          end
        end

        def completion_url
          "#{@provider.media_base}/v1/responses"
        end

        def server_tool_aliases
          SERVER_TOOL_ALIASES
        end

        private

        def provider_file_references?
          false
        end

        # MiniMax sends url_citation annotations with both offsets at 0, so
        # they say nothing about the span they support. Its content field is
        # the quoted snippet.
        def parse_annotations(annotations, _content)
          Array(annotations).filter_map do |annotation|
            next unless annotation['type'] == 'url_citation'

            Citation.new(url: annotation['url'], title: annotation['title'], cited_text: annotation['content'])
          end
        end

        def offset_citations(citations, *)
          citations
        end
      end
    end
  end
end

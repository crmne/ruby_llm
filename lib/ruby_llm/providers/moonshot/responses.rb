# frozen_string_literal: true

module RubyLLM
  module Providers
    class Moonshot
      # Moonshot's dialect of the OpenAI Responses API, the route to Kimi's
      # server-side web search. It holds no state: store is always false.
      # https://platform.kimi.ai/docs/api/responses
      class Responses < Protocols::Responses
        include Moonshot::Documents

        SERVER_TOOL_ALIASES = {
          web_search: { tool: { type: 'web_search' } }
        }.freeze

        def server_tool_aliases
          SERVER_TOOL_ALIASES
        end

        def web_search_sources?
          true
        end

        def apply_end_user(payload, identifier)
          payload.merge(safety_identifier: identifier)
        end

        # Kimi reads images only from data URIs, so remote images travel inline.
        def render_image(image, image_url: image.for_llm, **)
          super
        end

        private

        def provider_file_references?
          false
        end

        # Kimi silently drops the web_search tool for a message whose content
        # is a bare string, so text always travels as input_text parts.
        def render_item(msg, caching: nil)
          item = super
          return item unless item.is_a?(Hash) && item[:role] && item[:content].is_a?(String)

          item.merge(content: [{ type: 'input_text', text: item[:content] }])
        end

        def parse_server_tool_use(response)
          searches = Array(response['output']).count { |item| item['type'] == 'web_search_call' }
          searches.positive? ? { 'web_search_requests' => searches } : {}
        end
      end
    end
  end
end

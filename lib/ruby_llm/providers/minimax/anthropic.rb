# frozen_string_literal: true

module RubyLLM
  module Providers
    class MiniMax
      # MiniMax's dialect of the Anthropic Messages API. MiniMax has no
      # Files API on this endpoint, and web search is the one server tool it
      # runs, in Anthropic's first version.
      class Anthropic < Protocols::Anthropic
        SERVER_TOOL_ALIASES = {
          web_search: { tool: { type: 'web_search_20250305', name: 'web_search' } }
        }.freeze

        def render_payload(messages, tools:, schema: nil, tool_prefs: nil, **)
          raise ArgumentError, "MiniMax's Messages API has no structured output" if schema
          raise ArgumentError, 'MiniMax does not accept calls: :one' if tools.any? && tool_prefs&.dig(:calls) == :one

          super
        end

        def server_tool_aliases
          SERVER_TOOL_ALIASES
        end

        def provider_file_references?
          false
        end
      end
    end
  end
end

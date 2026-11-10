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

        RESPONSES_ITEMS = %w[reasoning web_search_call message function_call].freeze
        private_constant :RESPONSES_ITEMS

        def render_payload(messages, tools:, schema: nil, tool_prefs: nil, **)
          raise ArgumentError, "MiniMax's Messages API has no structured output" if schema
          raise ArgumentError, 'MiniMax does not accept calls: :one' if tools.any? && tool_prefs&.dig(:calls) == :one

          super
        end

        def render_count_tokens_payload(messages, tool_prefs: nil, **)
          super(messages, **, schema: nil, tool_prefs: tool_prefs&.except(:calls))
        end

        def server_tool_aliases
          SERVER_TOOL_ALIASES
        end

        def provider_file_references?
          false
        end

        private

        # A web search turn answered on Responses keeps that route's output
        # items, which a Messages request cannot carry.
        def foreign_native_content?(message)
          super || (message.role == :assistant && responses_output?(message.raw_content))
        end

        def responses_output?(raw_content)
          raw_content.is_a?(Array) && raw_content.any? do |item|
            item.is_a?(Hash) && RESPONSES_ITEMS.include?(item['type'])
          end
        end
      end
    end
  end
end

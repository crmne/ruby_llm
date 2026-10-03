# frozen_string_literal: true

module RubyLLM
  module Providers
    class Anthropic
      # Feature capability gaps not represented in upstream model catalogs.
      module Capabilities
        TOOL_CAPABILITIES = %w[tool_choice parallel_tool_calls].freeze

        # The models Anthropic lists as supporting the tool search tool:
        # https://platform.claude.com/docs/en/agents-and-tools/tool-use/tool-search-tool#model-compatibility
        TOOL_SEARCH_MODELS = %w[
          claude-fable-5
          claude-fable-5-1
          claude-haiku-4-5
          claude-haiku-4-5-20251001
          claude-opus-4-5
          claude-opus-4-5-20251101
          claude-opus-4-6
          claude-opus-4-7
          claude-opus-4-8
          claude-opus-5
          claude-opus-5-5
          claude-sonnet-4-5
          claude-sonnet-4-5-20250929
          claude-sonnet-4-6
          claude-sonnet-5
          claude-sonnet-5-5
        ].freeze

        def self.augment(capabilities, model_id:, **)
          return capabilities unless capabilities.include?('function_calling')

          supported = capabilities | TOOL_CAPABILITIES
          TOOL_SEARCH_MODELS.include?(model_id) ? supported | ['tool_search'] : supported
        end
      end
    end
  end
end

# frozen_string_literal: true

module RubyLLM
  module Providers
    class Anthropic
      # Feature capability gaps not represented in upstream model catalogs.
      module Capabilities
        TOOL_CAPABILITIES = %w[tool_choice parallel_tool_calls].freeze

        def self.augment(capabilities, **)
          return capabilities unless capabilities.include?('function_calling')

          capabilities | TOOL_CAPABILITIES
        end
      end
    end
  end
end

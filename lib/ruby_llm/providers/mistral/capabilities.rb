# frozen_string_literal: true

module RubyLLM
  module Providers
    class Mistral
      # Feature capability gaps not represented in upstream model catalogs.
      module Capabilities
        TOOL_CAPABILITIES = %w[tool_choice parallel_tool_calls].freeze
        STRUCTURED_OUTPUT_MODELS = %w[mistral-small-2603 mistral-small-latest].freeze

        def self.augment(capabilities, model_id:, **)
          capabilities |= TOOL_CAPABILITIES if capabilities.include?('function_calling')
          capabilities |= ['structured_output'] if STRUCTURED_OUTPUT_MODELS.include?(model_id)

          capabilities
        end
      end
    end
  end
end

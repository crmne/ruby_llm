# frozen_string_literal: true

module RubyLLM
  module Providers
    class Azure
      # Feature capability gaps not represented in upstream model catalogs.
      module Capabilities
        def self.augment(capabilities, model_id:, **)
          return capabilities unless model_id == 'grok-4-1-fast-non-reasoning'

          capabilities | %w[tool_choice parallel_tool_calls]
        end
      end
    end
  end
end

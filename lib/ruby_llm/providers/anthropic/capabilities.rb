# frozen_string_literal: true

module RubyLLM
  module Providers
    class Anthropic
      # Provider-level capability checks used outside the model registry.
      module Capabilities
        extend CapabilityTable

        module_function

        CAPABILITIES = {
          'citations' => ->(model_id) { !model_id.include?('claude-3-haiku') },
          'tool_choice' => true,
          'parallel_tool_calls' => true
        }.freeze

        def critical_capabilities_for(model_id) = supported_capabilities(model_id)
      end
    end
  end
end

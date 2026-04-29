# frozen_string_literal: true

module RubyLLM
  module Providers
    class Anthropic
      # Provider-level capability checks used outside the model registry.
      module Capabilities
        module_function

        def supports_tool_choice?(_model_id)
          true
        end

        def supports_tool_parallel_control?(_model_id)
          true
        end
      end
    end
  end
end

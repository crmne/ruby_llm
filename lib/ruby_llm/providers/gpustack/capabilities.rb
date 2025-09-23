# frozen_string_literal: true

module RubyLLM
  module Providers
    class GPUStack
      # Determines capabilities for GPUStack models
      module Capabilities
        module_function

        def supports_tool_choice?(_model_id)
          false
        end

        def supports_tool_parallel_control?(_model_id)
          false
        end
      end
    end
  end
end

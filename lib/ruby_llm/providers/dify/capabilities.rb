# frozen_string_literal: true

module RubyLLM
  module Providers
    module Dify
      module Capabilities
        module_function

        def capabilities_for(model_id)
          capabilities = ['streaming']
          capabilities
        end
      end
    end
  end
end

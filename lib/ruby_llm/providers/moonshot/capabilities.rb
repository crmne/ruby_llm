# frozen_string_literal: true

module RubyLLM
  module Providers
    class Moonshot
      # Feature capability gaps not represented in upstream model catalogs.
      module Capabilities
        def self.augment(capabilities, **)
          return capabilities unless capabilities.include?('function_calling')

          capabilities | ['tool_choice']
        end
      end
    end
  end
end

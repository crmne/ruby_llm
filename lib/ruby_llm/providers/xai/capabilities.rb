# frozen_string_literal: true

module RubyLLM
  module Providers
    class XAI
      # Feature capability gaps not represented in upstream model catalogs.
      module Capabilities
        def self.augment(capabilities, modalities:, **)
          return capabilities unless modalities[:output].include?('text')

          capabilities | ['streaming']
        end
      end
    end
  end
end

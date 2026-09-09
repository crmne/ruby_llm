# frozen_string_literal: true

module RubyLLM
  module Providers
    class XAI
      # Feature capability gaps not represented in upstream model catalogs.
      module Capabilities
        def self.augment(capabilities, model_id:, modalities:)
          return capabilities unless modalities[:output].include?('text')

          additions = ['streaming']
          additions.push('tool_choice', 'parallel_tool_calls') if model_id == 'grok-4.3'
          capabilities | additions
        end
      end
    end
  end
end

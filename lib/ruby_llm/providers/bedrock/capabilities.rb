# frozen_string_literal: true

module RubyLLM
  module Providers
    class Bedrock
      # Feature capability gaps not represented in upstream model catalogs.
      module Capabilities
        TOOL_CHOICE_MODELS = %w[amazon.nova-2-lite-v1:0 us.amazon.nova-2-lite-v1:0].freeze

        def self.augment(capabilities, model_id:, **)
          return capabilities unless TOOL_CHOICE_MODELS.include?(model_id)

          capabilities | ['tool_choice']
        end
      end
    end
  end
end

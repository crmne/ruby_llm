# frozen_string_literal: true

module RubyLLM
  module Providers
    class Gemini
      # Feature capability gaps not represented in upstream model catalogs.
      module Capabilities
        def self.augment(capabilities, model_id:, modalities:)
          additions = []
          additions << 'tool_choice' if capabilities.include?('function_calling')
          if !model_id.include?('embedding') &&
             modalities[:input].include?('audio') && modalities[:output].include?('text')
            additions << 'transcription'
          end
          capabilities | additions
        end
      end
    end
  end
end

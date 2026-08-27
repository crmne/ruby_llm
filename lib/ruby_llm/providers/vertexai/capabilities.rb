# frozen_string_literal: true

module RubyLLM
  module Providers
    class VertexAI
      # Feature capability gaps not represented in upstream model catalogs.
      module Capabilities
        def self.augment(capabilities, model_id:, modalities:)
          return capabilities if model_id.include?('embedding')
          return capabilities unless modalities[:input].include?('audio') && modalities[:output].include?('text')

          capabilities | ['transcription']
        end
      end
    end
  end
end

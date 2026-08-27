# frozen_string_literal: true

module RubyLLM
  module Providers
    class OpenAI
      # Feature capability gaps not represented in upstream model catalogs.
      module Capabilities
        TOOL_CAPABILITIES = %w[tool_choice parallel_tool_calls].freeze
        TRANSCRIPTION_MODELS = %w[
          gpt-4o-mini-transcribe
          gpt-4o-mini-transcribe-2025-03-20
          gpt-4o-mini-transcribe-2025-12-15
          gpt-4o-transcribe
          gpt-4o-transcribe-diarize
          whisper-1
        ].freeze

        def self.augment(capabilities, model_id:, modalities:)
          additions = []
          additions.concat(TOOL_CAPABILITIES) if capabilities.include?('function_calling')
          if TRANSCRIPTION_MODELS.include?(model_id) &&
             modalities[:input].include?('audio') && modalities[:output].include?('text')
            additions << 'transcription'
          end
          capabilities | additions
        end
      end
    end
  end
end

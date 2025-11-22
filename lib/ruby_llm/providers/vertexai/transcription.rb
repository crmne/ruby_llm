# frozen_string_literal: true

module RubyLLM
  module Providers
    class VertexAI
      # Vertex AI specific helpers for audio transcription
      module Transcription
        private

        def transcription_url(model)
          "projects/#{@config.vertexai_project_id}/locations/#{@config.vertexai_location}/publishers/google/models/#{model}:generateContent" # rubocop:disable Layout/LineLength
        end
      end
    end
  end
end

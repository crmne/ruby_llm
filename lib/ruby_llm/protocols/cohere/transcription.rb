# frozen_string_literal: true

module RubyLLM
  module Protocols
    class Cohere
      # Audio transcription methods for the Cohere v2 API integration
      module Transcription
        DEFAULT_LANGUAGE = 'en'

        module_function

        def transcription_url
          'v2/audio/transcriptions'
        end

        # Cohere parses the multipart body as it streams, so every form field
        # has to be written before the file part or the request is rejected as
        # missing them. The file goes in last, after provider options.
        # rubocop:disable-next Lint/UnusedMethodArgument
        def render_transcription_payload(file_part, model:, language:, format: nil, speaker_names: nil,
                                         speaker_references: nil, provider_options: {}, prompt: nil,
                                         temperature: nil)
          {
            model: model,
            language: language || DEFAULT_LANGUAGE,
            temperature: temperature
          }.compact.merge(provider_options).merge(file: file_part)
        end

        # Cohere Transcribe returns the transcript alone: no timestamps,
        # segments, or speaker labels.
        def parse_transcription_response(response, model:)
          data = response.body
          return RubyLLM::Transcription.new(text: data, model: model) if data.is_a?(String)

          RubyLLM::Transcription.new(text: data['text'], model: model)
        end
      end
    end
  end
end

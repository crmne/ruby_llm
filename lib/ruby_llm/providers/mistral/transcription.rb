# frozen_string_literal: true

module RubyLLM
  module Providers
    class Mistral
      # Transcription dialect for the Mistral audio API. Giving speaker
      # names turns on diarization, which labels each segment with a
      # speaker id; a prompt rides along as context biasing terms.
      module Transcription
        module_function

        # rubocop:disable Lint/UnusedMethodArgument
        def render_transcription_payload(file_part, model:, language:, format: nil, speaker_names: nil,
                                         speaker_references: nil, provider_options: {}, prompt: nil,
                                         temperature: nil)
          payload = {
            model: model,
            file: file_part,
            language: language,
            temperature: temperature,
            context_bias: prompt ? Array(prompt) : nil
          }.compact
          if speaker_names
            payload[:diarize] = true
            payload[:timestamp_granularities] = ['segment']
          end
          payload.merge(provider_options)
        end
        # rubocop:enable Lint/UnusedMethodArgument
      end
    end
  end
end

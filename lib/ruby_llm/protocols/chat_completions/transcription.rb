# frozen_string_literal: true

module RubyLLM
  module Protocols
    class ChatCompletions
      # Audio transcription methods for the OpenAI API integration
      module Transcription
        module_function

        def transcription_url
          'audio/transcriptions'
        end

        # rubocop:disable Metrics/ParameterLists
        def render_transcription_payload(file_part, model:, language:, format: nil, speaker_names: nil,
                                         speaker_references: nil, provider_options: {}, prompt: nil,
                                         temperature: nil)
          {
            model: model,
            file: file_part,
            language: language,
            chunking_strategy: default_chunking_strategy(model),
            response_format: format || default_response_format(model),
            prompt: prompt,
            temperature: temperature,
            known_speaker_names: speaker_names,
            known_speaker_references: encode_speaker_references(speaker_references)
          }.compact.merge(provider_options)
        end
        # rubocop:enable Metrics/ParameterLists

        def encode_speaker_references(references)
          return nil unless references

          references.map do |ref|
            Attachment.new(ref).for_llm
          end
        end

        def default_chunking_strategy(model)
          'auto' if model.include?('diarize')
        end

        def default_response_format(model)
          'diarized_json' if model.include?('diarize')
        end

        def parse_transcription_response(response, model:)
          data = response.body

          return RubyLLM::Transcription.new(text: data, model: model) if data.is_a?(String)

          usage = data['usage'] || {}

          RubyLLM::Transcription.new(
            text: data['text'],
            model: model,
            language: data['language'],
            duration: data['duration'],
            segments: data['segments'],
            words: data['words'],
            input_tokens: usage['input_tokens'] || usage['prompt_tokens'],
            output_tokens: usage['output_tokens'] || usage['completion_tokens']
          )
        end
      end
    end
  end
end

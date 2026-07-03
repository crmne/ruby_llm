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

        # rubocop:disable Lint/UnusedMethodArgument, Metrics/ParameterLists
        def render_transcription_payload(file_part, model:, language:, params: {}, prompt: nil, temperature: nil,
                                         response_format: nil, timestamp_granularities: nil, speaker_names: nil,
                                         speaker_references: nil, chunking_strategy: nil, response_mime_type: nil,
                                         max_output_tokens: nil, safety_settings: nil)
          {
            model: model,
            file: file_part,
            language: language,
            chunking_strategy: resolved_chunking_strategy(model, chunking_strategy),
            response_format: response_format_for(model, response_format),
            prompt: prompt,
            temperature: temperature,
            timestamp_granularities: timestamp_granularities,
            known_speaker_names: speaker_names,
            known_speaker_references: encode_speaker_references(speaker_references)
          }.compact.merge(params)
        end
        # rubocop:enable Lint/UnusedMethodArgument, Metrics/ParameterLists

        def encode_speaker_references(references)
          return nil unless references

          references.map do |ref|
            Attachment.new(ref).for_llm
          end
        end

        def resolved_chunking_strategy(model, chunking_strategy)
          return unless supports_chunking_strategy?(model, chunking_strategy)

          chunking_strategy || 'auto'
        end

        def response_format_for(model, response_format)
          return response_format if response_format

          'diarized_json' if model.include?('diarize')
        end

        def supports_chunking_strategy?(model, chunking_strategy)
          return false if model.start_with?('whisper')
          return true if chunking_strategy

          model.include?('diarize')
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

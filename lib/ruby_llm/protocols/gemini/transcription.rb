# frozen_string_literal: true

module RubyLLM
  module Protocols
    class Gemini
      # Audio transcription helpers for the Gemini API implementation
      module Transcription
        DEFAULT_PROMPT = 'Transcribe the provided audio and respond with only the transcript text.'

        # rubocop:disable Lint/UnusedMethodArgument, Metrics/ParameterLists
        def transcribe(audio_file, model:, language:, params: {}, prompt: nil, temperature: nil,
                       response_format: nil, timestamp_granularities: nil, speaker_names: nil,
                       speaker_references: nil, chunking_strategy: nil, response_mime_type: 'text/plain',
                       max_output_tokens: nil, safety_settings: nil)
          attachment = Attachment.new(audio_file)
          payload = render_transcription_payload(attachment, language:, params:, prompt:, temperature:,
                                                             response_mime_type:, max_output_tokens:, safety_settings:)
          response = @connection.post(transcription_url(model), payload)
          parse_transcription_response(response, model:)
        end
        # rubocop:enable Lint/UnusedMethodArgument, Metrics/ParameterLists

        private

        def transcription_url(model)
          "models/#{model}:generateContent"
        end

        def render_transcription_payload(attachment, language:, params: {}, prompt: nil, temperature: nil, # rubocop:disable Metrics/ParameterLists
                                         response_mime_type: 'text/plain', max_output_tokens: nil, safety_settings: nil)
          prompt = build_prompt(prompt, language)
          audio_part = format_audio_part(attachment)

          raise UnsupportedAttachmentError, attachment.mime_type unless attachment.audio?

          payload = {
            contents: [
              {
                role: 'user',
                parts: [
                  { text: prompt },
                  audio_part
                ]
              }
            ]
          }

          generation_config = build_generation_config(response_mime_type:, temperature:, max_output_tokens:)
          payload[:generationConfig] = generation_config unless generation_config.empty?
          payload[:safetySettings] = safety_settings if safety_settings

          Utils.deep_merge(payload, params)
        end

        def build_generation_config(response_mime_type:, temperature:, max_output_tokens:)
          config = {}

          config[:responseMimeType] = response_mime_type if response_mime_type
          config[:temperature] = temperature if temperature
          config[:maxOutputTokens] = max_output_tokens if max_output_tokens

          config
        end

        def build_prompt(custom_prompt, language)
          prompt = DEFAULT_PROMPT
          prompt += " Respond in the #{language} language." if language
          prompt += " #{custom_prompt}" if custom_prompt
          prompt
        end

        def format_audio_part(attachment)
          {
            inline_data: {
              mime_type: attachment.mime_type,
              data: attachment.encoded
            }
          }
        end

        def parse_transcription_response(response, model:)
          data = response.body
          text = extract_text(data)

          usage = extract_usage(data)

          RubyLLM::Transcription.new(
            text: text,
            model: model,
            input_tokens: usage[:input_tokens],
            output_tokens: usage[:output_tokens]
          )
        end

        def extract_text(data)
          candidate = data.is_a?(Hash) ? data.dig('candidates', 0) : nil
          return unless candidate

          parts = candidate.dig('content', 'parts') || []
          texts = parts.filter_map { |part| part['text'] }
          texts.join if texts.any?
        end

        def extract_usage(data)
          metadata = data.is_a?(Hash) ? data['usageMetadata'] : nil
          return { input_tokens: nil, output_tokens: nil } unless metadata

          {
            input_tokens: metadata['promptTokenCount'],
            output_tokens: sum_output_tokens(metadata)
          }
        end

        def sum_output_tokens(metadata)
          candidates = metadata['candidatesTokenCount'] || 0
          thoughts = metadata['thoughtsTokenCount'] || 0
          candidates + thoughts
        end
      end
    end
  end
end

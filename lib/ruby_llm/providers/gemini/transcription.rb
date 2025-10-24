# frozen_string_literal: true

module RubyLLM
  module Providers
    class Gemini
      # Audio transcription helpers for the Gemini API implementation
      module Transcription
        DEFAULT_PROMPT = 'Transcribe the provided audio and respond with only the transcript text.'

        def transcribe(audio_file, model:, language:, **options)
          attachment = Attachment.new(audio_file)
          payload = render_transcription_payload(attachment, language:, **options)
          response = @connection.post(transcription_url(model), payload)
          parse_transcription_response(response, model:)
        end

        private

        def transcription_url(model)
          "models/#{model}:generateContent"
        end

        def render_transcription_payload(attachment, language:, **options)
          prompt = build_prompt(options[:prompt], language)
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

          generation_config = build_generation_config(options)
          payload[:generationConfig] = generation_config unless generation_config.empty?
          payload[:safetySettings] = options[:safety_settings] if options[:safety_settings]

          payload
        end

        def build_generation_config(options)
          config = {}
          response_mime_type = options.fetch(:response_mime_type, 'text/plain')

          config[:responseMimeType] = response_mime_type if response_mime_type
          config[:temperature] = options[:temperature] if options.key?(:temperature)
          config[:maxOutputTokens] = options[:max_output_tokens] if options[:max_output_tokens]

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

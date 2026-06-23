# frozen_string_literal: true

module RubyLLM
  module Protocols
    class ChatCompletions
      # Speech generation methods for the OpenAI API integration
      module Speech
        module_function

        def speech_url(model:) # rubocop:disable Lint/UnusedMethodArgument
          'audio/speech'
        end

        def render_speech_payload(input, model:, voice:, format:, params: {}, **options) # rubocop:disable Metrics/ParameterLists
          {
            model: model,
            input: input,
            voice: voice || 'alloy',
            response_format: format,
            instructions: options[:instructions],
            speed: options[:speed]
          }.compact.merge(params)
        end

        def parse_speech_response(response, model:, voice:, format:)
          resolved_format = (format || 'mp3').to_s

          RubyLLM::Speech.new(
            data: response.body,
            model: model,
            voice: voice || 'alloy',
            format: resolved_format
          )
        end
      end
    end
  end
end

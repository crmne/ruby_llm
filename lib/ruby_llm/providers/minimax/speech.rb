# frozen_string_literal: true

module RubyLLM
  module Providers
    class MiniMax
      # MiniMax synchronous and asynchronous text-to-audio operations.
      module Speech
        module_function

        def speech_url(model:) # rubocop:disable Lint/UnusedMethodArgument
          't2a_v2'
        end

        def render_speech_payload(input, model:, voice:, format:, provider_options: {})
          payload = {
            model: model,
            text: input,
            stream: false,
            output_format: 'hex',
            voice_setting: voice && { voice_id: voice },
            audio_setting: format && { format: format.to_s }
          }.compact
          Utils.deep_merge(payload, provider_options)
        end

        def parse_speech_response(response, model:, voice:, format:)
          body = response.body
          validate_response!(body)
          audio = value(value(body, :data), :audio)
          raise Error, 'MiniMax did not return speech audio' unless audio

          RubyLLM::Speech.new(
            data: [audio].pack('H*'),
            model: model,
            voice: voice,
            format: (format || 'mp3').to_s
          )
        end

        def synthesize_async(input, model:, voice: nil, provider_options: {})
          payload = render_speech_payload(input, model:, voice:, format: nil, provider_options:)
          payload.delete(:stream)
          payload.delete(:output_format)
          validate_response!(@connection.post('t2a_async_v2', payload).body)
        end

        def speech_task(task_id)
          validate_response!(@connection.post('query/t2a_async_query_v2', task_id: task_id).body)
        end

        def validate_response!(body)
          status = value(value(body, :base_resp), :status_code)
          raise Error, "MiniMax speech request failed with status #{status}" if status && !status.zero?

          body
        end

        def value(hash, key)
          hash&.[](key) || hash&.[](key.to_s)
        end
      end
    end
  end
end

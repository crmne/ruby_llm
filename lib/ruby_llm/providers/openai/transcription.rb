# frozen_string_literal: true

module RubyLLM
  module Providers
    module OpenAI
      # Handles audio transcription functionality for the OpenAI API
      module Transcription
        # Helper methods as module_function

        module_function

        def self.extended(base)
          # module_function causes the 'transcribe' method to be private, but we need it to be public
          base.public_class_method :transcribe
        end

        def self.transcribe(audio_file, model: nil, language: nil)
          model ||= RubyLLM.config.default_transcription_model
          payload = render_transcription_payload(audio_file, model: model, language: language)

          response = post_multipart(transcription_url, payload)
          parse_transcription_response(response)
        end

        def transcription_url
          "#{api_base}/audio/transcriptions"
        end

        def api_base
          'https://api.openai.com/v1'
        end

        def headers
          {
            'Authorization' => "Bearer #{RubyLLM.config.openai_api_key}"
          }
        end

        def post_multipart(url, payload)
          connection = Faraday.new(url: api_base) do |f|
            f.request :multipart
            f.request :url_encoded
            f.adapter Faraday.default_adapter
          end

          response = connection.post(url) do |req|
            req.headers.merge!(headers)
            req.body = payload
          end

          JSON.parse(response.body)
        end

        def render_transcription_payload(audio_file, model:, language: nil)
          file_part = Faraday::Multipart::FilePart.new(audio_file, Content.mime_type_for(audio_file))

          payload = {
            model: model,
            file: file_part
          }

          # Add language if provided
          payload[:language] = language if language

          payload
        end

        def parse_transcription_response(response)
          response['text']
        end
      end
    end
  end
end

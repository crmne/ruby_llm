# frozen_string_literal: true

require 'uri'

module RubyLLM
  module Protocols
    class Deepgram
      # Transcription dialect for the Deepgram speech-to-text API. Every
      # option is a query parameter on v1/listen, and the body is either the
      # audio bytes or a JSON pointer to a remote url. Giving speaker names
      # turns on diarization, which labels each word and utterance with a
      # numeric speaker index.
      module Transcription
        # Turned on by default so the transcript reads like the transcripts
        # every other provider returns. Smart formatting punctuates and
        # formats numbers, dates, and currency; utterances split the
        # transcript into timed segments.
        DEFAULT_PARAMS = { smart_format: true, utterances: true }.freeze

        # The batch diarizer to run. 'latest' tracks Deepgram's current
        # generally available diarizer, which the boolean diarize parameter
        # it deprecates does not.
        DIARIZE_MODEL = 'latest'

        # rubocop:disable-next Lint/UnusedMethodArgument
        def transcribe(audio_file, model:, language:, format: nil, speaker_names: nil,
                       speaker_references: nil, provider_options: {}, prompt: nil, temperature: nil)
          raise_transcription_streaming_unsupported if block_given?

          track_usage(:transcription) do
            attachment = Attachment.new(audio_file)
            url = transcription_url(model:, language:, speaker_names:, provider_options:)
            payload = render_transcription_payload(attachment)
            response = post_transcription(url, payload, attachment)
            parse_transcription_response(response, model:)
          end
        end

        def transcription_url(model:, language: nil, speaker_names: nil, provider_options: {})
          "v1/listen?#{URI.encode_www_form(transcription_params(model:, language:, speaker_names:,
                                                                provider_options:))}"
        end

        def transcription_params(model:, language: nil, speaker_names: nil, provider_options: {})
          params = { model: model, language: language }.merge(DEFAULT_PARAMS)
          params[:diarize_model] = DIARIZE_MODEL if speaker_names
          params.merge(provider_options).compact
        end

        # Deepgram fetches remote audio itself, so a url attachment is sent
        # as a JSON pointer and everything else is uploaded as raw bytes.
        def render_transcription_payload(attachment)
          return { url: attachment.source.to_s } if attachment.url?

          attachment.content
        end

        def parse_transcription_response(response, model:)
          data = response.body || {}
          channel = data.dig('results', 'channels', 0) || {}
          alternative = channel.dig('alternatives', 0) || {}

          RubyLLM::Transcription.new(
            text: alternative['transcript'],
            model: model,
            language: channel['detected_language'],
            duration: data.dig('metadata', 'duration'),
            segments: data.dig('results', 'utterances'),
            words: alternative['words']
          )
        end

        private

        def post_transcription(url, payload, attachment)
          @connection.post(url, payload, usage: @usage_tracker) do |request|
            request.headers['Content-Type'] = attachment.mime_type || 'application/octet-stream' unless attachment.url?
          end
        end
      end
    end
  end
end

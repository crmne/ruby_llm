# frozen_string_literal: true

module RubyLLM
  module Providers
    class Deepgram
      # Audio transcription methods for the Deepgram API integration
      module Transcription
        TRANSCRIPTION_OPTIONS = %i[
          diarize punctuate smart_format paragraphs utterances
          detect_language filler_words profanity_filter numerals
          measurements dictation redact keywords summarize
          topics sentiment intents detect_entities
        ].freeze

        def transcribe(audio_file, model:, language:, **options)
          url = build_transcription_url(model:, language:, **options)

          response = if url?(audio_file)
                       post_url_transcription(url, audio_file)
                     else
                       post_file_transcription(url, audio_file)
                     end

          parse_transcription_response(response, model:)
        end

        private

        def build_transcription_url(model:, language:, **options)
          params = { model: model }
          params[:language] = language if language

          TRANSCRIPTION_OPTIONS.each do |opt|
            params[opt] = options[opt] if options.key?(opt)
          end

          query = URI.encode_www_form(params)
          "listen?#{query}"
        end

        def post_url_transcription(url, audio_url)
          @connection.post(url, { url: audio_url })
        end

        def post_file_transcription(url, file_path)
          expanded_path = File.expand_path(file_path)
          audio_data = File.binread(expanded_path)
          content_type = Marcel::MimeType.for(Pathname.new(expanded_path))

          @connection.post(url, audio_data) do |req|
            req.headers['Content-Type'] = content_type
          end
        end

        def url?(source)
          source.is_a?(String) && source.match?(%r{^https?://})
        end

        def parse_transcription_response(response, model:)
          data = response.body
          results = data['results'] || {}
          channels = results['channels'] || []
          metadata = data['metadata'] || {}

          transcript = channels.dig(0, 'alternatives', 0, 'transcript') || ''
          segments = extract_segments(channels)

          RubyLLM::Transcription.new(
            text: transcript,
            model: model,
            language: channels.dig(0, 'detected_language'),
            duration: metadata['duration'],
            segments: segments
          )
        end

        def extract_segments(channels)
          return nil if channels.empty?

          words = channels.dig(0, 'alternatives', 0, 'words') || []
          return nil if words.empty?

          words.map do |word|
            {
              'word' => word['word'],
              'start' => word['start'],
              'end' => word['end'],
              'confidence' => word['confidence'],
              'speaker' => word['speaker']
            }.compact
          end
        end
      end
    end
  end
end

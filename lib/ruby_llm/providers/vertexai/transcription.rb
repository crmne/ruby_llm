# frozen_string_literal: true

module RubyLLM
  module Providers
    class VertexAI
      class Transcription < VertexAI::Gemini # :nodoc: all
        def render_transcription_options(timestamps:, **)
          return {} if timestamps.nil?
          raise ArgumentError, 'Vertex AI transcription timestamps must be word' unless timestamps == :word

          { generationConfig: { audioTranscriptionConfig: { wordTimestamp: true } } }
        end

        include Protocols::Gemini::FileTranscription

        def validate_transcription_request(...)
          super
          return if @config.vertexai_location == 'global'

          raise ArgumentError, 'Vertex AI dedicated transcription requires vertexai_location = "global"'
        end

        def render_transcription_payload(attachment, language:, speaker_names:, provider_options:, prompt:, **)
          config = { languageCodes: language && Array(language), customVocabulary: prompt && Array(prompt),
                     diarization: speaker_names && true }.compact
          payload = { contents: [{ role: 'user', parts: [format_audio_part(attachment)] }],
                      generationConfig: { audioTranscriptionConfig: config } }
          Support::Utils.deep_merge(payload, provider_options)
        end

        private

        def parse_transcription_response(response, model:)
          data = response.body
          parts = data.dig('candidates', 0, 'content', 'parts') || []
          segments = parts.filter_map { |part| parse_transcription_segment(part) }
          text = parts.filter_map { |part| part['text'] || part.dig('audioTranscription', 'text') }.join
          words = segments.flat_map { |segment| segment['words'] }
          RubyLLM::Transcription.new(text:, model:, segments: segments.empty? ? nil : segments,
                                     words: words.empty? ? nil : words, **extract_usage(data))
        end

        def parse_transcription_segment(part)
          transcription = part['audioTranscription']
          return unless transcription

          { 'text' => part['text'] || transcription['text'], 'speaker' => transcription['speakerLabel'],
            'words' => Array(transcription['words']).map do |word|
              parse_transcription_word(word, transcription)
            end }.compact
        end

        def parse_transcription_word(word, transcription)
          { 'word' => word['word'], 'speaker' => transcription['speakerLabel'],
            'start' => word['startOffset'] && Float(word['startOffset'].delete_suffix('s')),
            'end' => word['endOffset'] && Float(word['endOffset'].delete_suffix('s')) }.compact
        end
      end
    end
  end
end

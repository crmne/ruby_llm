# frozen_string_literal: true

module RubyLLM
  module Protocols
    class Interactions
      module Transcription # :nodoc: all
        def render_transcription_options(timestamps:, **)
          return {} if timestamps.nil?
          raise ArgumentError, 'Gemini transcription timestamps must be word' unless timestamps == :word

          { generation_config: { transcription_config: { mode: { type: 'verbatim',
                                                                 timestamp_granularities: ['word'] } } } }
        end

        include Gemini::FileTranscription

        def transcription_url(_model)
          'interactions'
        end

        def render_transcription_payload(attachment, model:, language:, speaker_names:, provider_options:, prompt:)
          config = { language_codes: language && Array(language), custom_vocabulary: prompt && Array(prompt) }.compact
          config[:mode] = { type: 'verbatim', diarization_mode: 'speaker' } if speaker_names
          payload = { model:, store: false,
                      input: [{ type: 'audio', mime_type: attachment.mime_type, data: attachment.encoded }],
                      generation_config: { transcription_config: config } }
          payload = Support::Utils.deep_merge(payload, provider_options)
          validate_transcription_config(payload.dig(:generation_config, :transcription_config))
          payload
        end

        def validate_transcription_config(config)
          mode = config[:mode]
          return unless config[:custom_vocabulary] && mode.is_a?(Hash)
          return unless mode[:diarization_mode] || mode[:timestamp_granularities]

          raise ArgumentError, 'Gemini custom vocabulary cannot be combined with diarization or word timestamps'
        end

        def parse_transcription_response(response, model:)
          data = response.body
          message = parse_completion_body(data, raw: response)
          annotations = Array(data['steps']).flat_map { |step| Array(step['content']) }
                                            .flat_map { |part| Array(part['annotations']) }
          words = annotations.filter_map { |item| parse_transcription_word(item) if item['type'] == 'word_info' }
          RubyLLM::Transcription.new(text: message.content, model:, words: words.empty? ? nil : words,
                                     **parse_interaction_usage(data['usage'] || {}))
        end

        def parse_transcription_word(word)
          { 'word' => word['text'], 'speaker' => word['speaker'],
            'start' => word['start_offset'] && Float(word['start_offset'].delete_suffix('s')),
            'end' => word['end_offset'] && Float(word['end_offset'].delete_suffix('s')) }.compact
        end
      end
    end
  end
end

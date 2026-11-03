# frozen_string_literal: true

require 'base64'

module RubyLLM
  module Protocols
    module VertexAI
      # Google Cloud Text-to-Speech, served from the endpoint of the
      # configured location. A voice name is locale, model, and voice:
      # de-DE-Chirp3-HD-Leda speaks German, and a bare Leda on Chirp3-HD is
      # en-US-Chirp3-HD-Leda.
      class TextToSpeech < Protocol
        MODELS = %w[Chirp3-HD].freeze

        DEFAULT_VOICE = 'Charon'
        DEFAULT_LOCALE = 'en-US'
        DEFAULT_FORMAT = 'mp3'

        # RubyLLM format names in Cloud Text-to-Speech's audioEncoding
        # vocabulary. LINEAR16, MULAW, and ALAW come back in a WAV container.
        ENCODINGS = {
          'mp3' => 'MP3',
          'wav' => 'LINEAR16',
          'opus' => 'OGG_OPUS',
          'mulaw' => 'MULAW',
          'alaw' => 'ALAW'
        }.freeze

        # Request fields that choose the text, voice, or encoding RubyLLM
        # reports, which provider_options may not replace in either JSON
        # spelling (languageCode or language_code).
        RESERVED_OPTIONS = {
          'input' => %w[text ssml markup multispeakermarkup],
          'voice' => %w[name languagecode customvoice voiceclone],
          'audioconfig' => %w[audioencoding]
        }.freeze

        MIME_TYPES = {
          'opus' => 'audio/ogg',
          'mulaw' => 'audio/wav',
          'alaw' => 'audio/wav'
        }.freeze

        def initialize(provider, model = nil)
          super
          @connection = provider.text_to_speech_connection
        end

        def speech_url(**)
          'text:synthesize'
        end

        def render_speech_payload(input, model:, voice:, format:, provider_options: {})
          options = Support::Utils.deep_stringify_keys(provider_options || {})
          reject_reserved_options(options)

          name = voice_name(voice, model)
          payload = {
            'input' => { 'text' => input },
            'voice' => { 'languageCode' => name.split('-').first(2).join('-'), 'name' => name },
            'audioConfig' => { 'audioEncoding' => encoding_for(format) }
          }
          Support::Utils.deep_merge(payload, options)
        end

        def parse_speech_response(response, model:, voice:, format:)
          audio = response.body['audioContent'] if response.body.is_a?(Hash)
          raise Error.new('Cloud Text-to-Speech returned no audio', response:) unless audio

          format = format_for(format)
          RubyLLM::Speech.new(data: Base64.decode64(audio), model:, voice: voice_name(voice, model), format:,
                              mime_type: MIME_TYPES[format])
        end

        private

        def reject_reserved_options(options)
          reserved = options.flat_map do |section, fields|
            keys = RESERVED_OPTIONS[field_key(section)]
            next [] unless keys && fields.is_a?(Hash)

            fields.keys.select { |key| keys.include?(field_key(key)) }.map { |key| "#{section}.#{key}" }
          end
          return if reserved.empty?

          raise ArgumentError, 'Use the input, voice:, and format: arguments instead of provider_options for ' \
                               "#{reserved.join(', ')}"
        end

        def field_key(key)
          key.delete('_').downcase
        end

        def voice_name(voice, model)
          voice = (voice || DEFAULT_VOICE).to_s
          voice.include?('-') ? voice : "#{DEFAULT_LOCALE}-#{model}-#{voice}"
        end

        def encoding_for(format)
          format = format_for(format)
          ENCODINGS.fetch(format, format.upcase)
        end

        def format_for(format)
          format = (format || DEFAULT_FORMAT).to_s
          ENCODINGS.key(format.upcase) || format.downcase
        end
      end
    end
  end
end

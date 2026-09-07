# frozen_string_literal: true

module RubyLLM
  module Protocols
    module Perplexity
      # Perplexity Router's Chat Completions dialect.
      class Router < ChatCompletions
        REJECTED_OPTIONS = %i[seed logit_bias top_logprobs functions function_call modalities audio prediction
                              web_search_options moderation verbosity].freeze
        DEFAULT_OPTIONS = { n: 1, logprobs: false, store: false, presence_penalty: 0, frequency_penalty: 0 }.freeze
        private_constant :REJECTED_OPTIONS, :DEFAULT_OPTIONS

        def completion_url
          @provider.router_url('chat/completions')
        end

        def render(...)
          super.tap do |payload|
            validate_router_options(payload)
            validate_router_tools(payload[:tools])
          end
        end

        def render_payload(messages, schema: nil, **options)
          if schema && schema[:strict] == false
            raise ArgumentError, 'Perplexity Router requires strict structured output'
          end

          super(messages, schema: schema&.merge(strict: true), **options)
        end

        def format_audio(audio)
          raise UnsupportedAttachmentError, audio.mime_type unless %w[mp3 wav].include?(audio.format)

          super
        end

        private

        def validate_router_options(payload)
          unsupported = payload.keys & REJECTED_OPTIONS
          unsupported.concat(DEFAULT_OPTIONS.keys.select do |key|
            payload.key?(key) && payload[key] != DEFAULT_OPTIONS[key]
          end)
          unsupported << :include_obfuscation if payload.dig(:stream_options, :include_obfuscation)
          return if unsupported.empty?

          raise ArgumentError, "Perplexity Router does not support these options: #{unsupported.join(', ')}"
        end

        def validate_router_tools(tools)
          return if Array(tools).all? { |tool| tool.dig(:function, :description).is_a?(String) }

          raise ArgumentError, 'Perplexity Router function tools require a description'
        end
      end
    end
  end
end

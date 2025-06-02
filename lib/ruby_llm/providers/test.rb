# frozen_string_literal: true

module RubyLLM
  module Providers
    # TestProvider is a mock provider for testing purposes.
    module Test
      # extend Provider

      module_function

      def complete(...)
        RubyLLM::Message.new(role: :assistant, content: 'Default response from TestProvider')
      end

      def list_models(...)
        [
          Model::Info.new(
            id: 'test',
            display_name: 'test',
            provider: 'test',
            family: 'test',
            type: 'chat',
            context_window: 100_000_000,
            max_tokens: 200_000_000,
            supports_vision: false,
            supports_functions: false,
            supports_json_mode: false,
            input_price_per_million: 0,
            output_price_per_million: 0,
            modalities: { input: ['text'], output: ['text'] },
            created_at: '2025-06-01 00:00:00 +0100'
          )
        ]
      end

      def configured?(...)
        true
      end

      def slug
        'test'
      end

      def local?
        true
      end

      def remote?
        true
      end

      def connection(...)
        nil
      end
    end
  end
end

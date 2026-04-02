# frozen_string_literal: true

module RubyLLM
  module Providers
    # Anthropic Claude API integration.
    class Anthropic < Provider
      include Anthropic::Chat
      include Anthropic::Embeddings
      include Anthropic::Media
      include Anthropic::Models
      include Anthropic::Streaming
      include Anthropic::Tools

      def api_base
        @config.anthropic_api_base || 'https://api.anthropic.com'
      end

      def headers
        {
          'x-api-key' => @config.anthropic_api_key,
          'anthropic-version' => '2023-06-01'
        }
      end

      # rubocop:disable Metrics/ParameterLists
      def complete(messages, tools:, temperature:, model:, params: {}, headers: {}, schema: nil, thinking: nil,
                   tool_prefs: nil, &block)
        headers = headers.merge('anthropic-beta' => 'prompt-caching-2024-07-31') if messages.any?(&:cache_point?)

        super
      end
      # rubocop:enable Metrics/ParameterLists

      class << self
        def capabilities
          Anthropic::Capabilities
        end

        def configuration_options
          %i[anthropic_api_key anthropic_api_base]
        end

        def configuration_requirements
          %i[anthropic_api_key]
        end
      end
    end
  end
end

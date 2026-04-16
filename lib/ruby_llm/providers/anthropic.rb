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

      def complete(messages, headers: {}, **kwargs, &block)
        headers = headers.merge('anthropic-beta' => 'prompt-caching-2024-07-31') if messages.any?(&:cache_point?)

        super(messages, headers: headers, **kwargs, &block) # rubocop:disable Style/SuperArguments
        # Ignoring as we're modifying headers before calling super. We need to call super with modified headers.
      end

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

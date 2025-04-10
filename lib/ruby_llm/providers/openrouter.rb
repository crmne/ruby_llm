# frozen_string_literal: true

module RubyLLM
  module Providers
    # OpenRouter API integration. Handles chat completion, function calling,
    # and streaming. Supports OpenRouter models.
    module OpenRouter
      extend Provider
      extend OpenRouter::Chat
      extend OpenRouter::Models
      extend OpenRouter::Streaming
      extend OpenRouter::Tools
      extend OpenRouter::Media

      def self.extended(base)
        base.extend(Provider)
        base.extend(OpenRouter::Chat)
        base.extend(OpenRouter::Models)
        base.extend(OpenRouter::Streaming)
        base.extend(OpenRouter::Tools)
        base.extend(OpenRouter::Media)
      end

      module_function

      def api_base
        'https://openrouter.ai/api/v1'
      end

      def headers
        {
          'Authorization' => "Bearer #{RubyLLM.config.openrouter_api_key}"
        }
      end

      def capabilities
        OpenRouter::Capabilities
      end

      def slug
        'openrouter'
      end

      def configuration_requirements
        %i[openrouter_api_key]
      end
    end
  end
end

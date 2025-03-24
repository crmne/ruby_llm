# frozen_string_literal: true

module RubyLLM
  module Providers
    # Anthropic API integration. Handles chat completion with Claude models,
    # including Claude 3 Opus, Sonnet, and Haiku.
    module Anthropic
      extend Provider
      extend Anthropic::Chat
      extend Anthropic::Models
      extend Anthropic::Streaming
      extend Anthropic::Tools
      extend Anthropic::Media
      extend Anthropic::Embeddings
      extend Anthropic::Schema

      module_function

      def api_base
        'https://api.anthropic.com'
      end

      def headers
        {
          'x-api-key' => RubyLLM.config.anthropic_api_key,
          'anthropic-version' => '2023-06-01'
        }
      end

      def capabilities
        Anthropic::Capabilities
      end

      def slug
        'anthropic'
      end
    end
  end
end

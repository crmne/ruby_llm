# frozen_string_literal: true

module RubyLLM
  module Providers
    # Perplexity API integration. Handles chat completion, streaming,
    # and Perplexity's unique features like citations.
    module Perplexity
      extend Provider
      extend Perplexity::Chat
      extend Perplexity::Models
      extend Perplexity::Streaming

      def self.extended(base)
        base.extend(Provider)
        base.extend(Perplexity::Chat)
        base.extend(Perplexity::Models)
        base.extend(Perplexity::Streaming)
      end

      module_function

      def api_base
        'https://api.perplexity.ai'
      end

      def headers
        {
          'Authorization' => "Bearer #{RubyLLM.config.perplexity_api_key}",
          'Content-Type'  => 'application/json'
        }
      end

      def capabilities
        Perplexity::Capabilities
      end

      def slug
        'perplexity'
      end
    end
  end
end

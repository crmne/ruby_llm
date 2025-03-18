# frozen_string_literal: true

module RubyLLM
  module Providers
    # DeepSeek API integration.
    module Perplexity
      extend OpenAI

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

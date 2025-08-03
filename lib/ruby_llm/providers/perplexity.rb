# frozen_string_literal: true

module RubyLLM
  module Providers
    # Perplexity API integration.
    module Perplexity
      extend OpenAI
      extend Perplexity::Chat
      extend Perplexity::Models

      module_function

      def api_base(_config)
        'https://api.perplexity.ai'
      end

      def headers(config)
        {
          'Authorization' => "Bearer #{config.perplexity_api_key}",
          'Content-Type' => 'application/json'
        }
      end

      def capabilities
        Perplexity::Capabilities
      end

      def slug
        'perplexity'
      end

      def configuration_requirements
        %i[perplexity_api_key]
      end

      def parse_error(response)
        body = response.body
        return if body.empty?

        # If response is HTML (Perplexity returns HTML for auth errors)
        if body.include?('<html>') && body.include?('<title>')
          # Extract title content
          title_match = body.match(%r{<title>(.+?)</title>})
          if title_match
            # Clean up the title - remove status code if present
            message = title_match[1]
            message = message.sub(/^\d+\s+/, '') # Remove leading digits and space
            return message
          end
        end

        # Fall back to parent's implementation
        super
      end
    end
  end
end

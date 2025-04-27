module RubyLLM
  module Providers
    # Mistral API integration. Handles chat completion, embeddings,
    # and Mistral's streaming format. Supports Mistral models.
    module Mistral
      extend Provider
      extend Mistral::Chat
      extend Mistral::Embeddings
      extend Mistral::Models
      extend Mistral::Streaming
      extend Mistral::Tools
      extend Mistral::Capabilities
      extend Mistral::Media
      # Mistral::Images removed as API doesn't support image generation

      def self.extended(base)
        base.extend(Provider)
        base.extend(Mistral::Chat)
        base.extend(Mistral::Embeddings)
        base.extend(Mistral::Models)
        base.extend(Mistral::Streaming)
        base.extend(Mistral::Tools)
        base.extend(Mistral::Capabilities)
        base.extend(Mistral::Media)
      end

      module_function

      def api_base(config)
        config.mistral_api_base || 'https://api.mistral.ai/v1'
      end

      # Add provider-specific error parsing
      def parse_error(response)
        return if response.body.empty?

        body = try_parse_json(response.body)
        error_message = case body
        when Hash
          # Check for standard { detail: [{ msg: ... }] } structure
          if body['detail'].is_a?(Array)
            body['detail'].map { |err| err['msg'] }.join("; ")
          # Check for simple { message: ... } structure (some Mistral errors use this)
          elsif body['message']
            body['message']
          # Fallback for other hash structures
          else
            body.to_s
          end
        else
          body.to_s # Return raw body if not a hash
        end

        # Format the error message
        if error_message.include?('Input should be a valid')
          "Invalid message format: The message content is not properly formatted"
        else
          error_message
        end
      end

      def headers(config)
        {
          'Authorization' => "Bearer #{config.mistral_api_key}"
        }
      end

      def capabilities
        Mistral::Capabilities
      end

      def slug
        'mistral'
      end

      def configuration_requirements
        %i[mistral_api_key]
      end
    end
  end
end

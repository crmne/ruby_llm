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

      def api_base
        'https://api.mistral.ai/v1'
      end

      def headers
        {
          'Authorization' => "Bearer #{RubyLLM.config.mistral_api_key}"
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

# frozen_string_literal: true

module RubyLLM
  module Providers
    # Mistral API integration.
    class Mistral < Provider
      # Mistral's dialect of the Chat Completions API.
      class ChatCompletions < Protocols::ChatCompletions
        include Mistral::Chat
        include Mistral::Embeddings
        include Mistral::Media
        include Mistral::Models
      end

      protocol :chat_completions, ChatCompletions

      def api_base
        @config.mistral_api_base || 'https://api.mistral.ai/v1'
      end

      def headers
        {
          'Authorization' => "Bearer #{@config.mistral_api_key}"
        }
      end

      class << self
        def capabilities
          Mistral::Capabilities
        end

        def configuration_options
          %i[mistral_api_key mistral_api_base]
        end

        def configuration_requirements
          %i[mistral_api_key]
        end
      end
    end
  end
end

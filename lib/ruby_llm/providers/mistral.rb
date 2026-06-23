# frozen_string_literal: true

module RubyLLM
  module Providers
    # Mistral API integration.
    class Mistral < Provider
      protocol :chat_completions, ChatCompletions, batches: Mistral::ChatCompletions::Batches
      files Mistral::Files

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

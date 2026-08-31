# frozen_string_literal: true

module RubyLLM
  module Providers
    # Mistral API integration.
    class Mistral < Provider
      protocol :chat_completions, ChatCompletions, batches: Mistral::ChatCompletions::Batches
      protocol :files, Protocols::Mistral::Files

      def api_base
        @config.mistral_api_base || 'https://api.mistral.ai/v1'
      end

      def headers
        {
          'Authorization' => "Bearer #{@config.mistral_api_key}"
        }
      end

      def batch_cost_multiplier(**) = 0.5

      class << self
        def capabilities
          Mistral::Capabilities
        end

        def models_dev_alias(...)
          Mistral::Models.models_dev_alias(...)
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

# frozen_string_literal: true

module RubyLLM
  module Providers
    # Anthropic Claude API integration.
    class Anthropic < Provider
      protocol :anthropic, Protocols::Anthropic, batches: Protocols::Anthropic::Batches
      protocol :files, Protocols::Anthropic::Files

      def api_base
        @config.anthropic_api_base || 'https://api.anthropic.com'
      end

      def headers
        {
          'x-api-key' => @config.anthropic_api_key,
          'anthropic-version' => '2023-06-01'
        }
      end

      def account_identity
        account_digest(api_base, @config.anthropic_api_key)
      end

      def batch_cost_multiplier(**) = 0.5

      class << self
        def capabilities
          Anthropic::Capabilities
        end

        def thinking_off_control(model_id)
          { enabled: false } if Protocols::Anthropic::Chat.between_tools_off_model?(model_id)
        end

        def configuration_options
          %i[anthropic_api_key anthropic_api_base]
        end

        def configuration_requirements
          %i[anthropic_api_key]
        end
      end
    end
  end
end

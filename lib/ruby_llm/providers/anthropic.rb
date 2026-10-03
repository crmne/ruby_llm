# frozen_string_literal: true

module RubyLLM
  module Providers
    # Anthropic Claude API integration.
    class Anthropic < Provider
      SONNET_55_MODEL_IDS = %w[claude-sonnet-5-5 anthropic.claude-sonnet-5-5].freeze
      private_constant :SONNET_55_MODEL_IDS

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

        def between_tools_off?(model_id) # :nodoc:
          SONNET_55_MODEL_IDS.include?(model_id.to_s)
        end

        def thinking_off_control(model_id) # :nodoc:
          { enabled: false } if between_tools_off?(model_id)
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

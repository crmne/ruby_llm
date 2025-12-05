# frozen_string_literal: true

module RubyLLM
  module Providers
    # Anthropic Claude API integration.
    class Anthropic < Provider
      include Anthropic::Chat
      include Anthropic::Embeddings
      include Anthropic::Media
      include Anthropic::Models
      include Anthropic::Streaming
      include Anthropic::Tools

      STRUCTURED_OUTPUTS_BETA = 'structured-outputs-2025-11-13'

      def api_base
        'https://api.anthropic.com'
      end

      def headers
        {
          'x-api-key' => @config.anthropic_api_key,
          'anthropic-version' => '2023-06-01'
        }
      end

      def complete(messages, tools:, temperature:, model:, params: {}, headers: {}, schema: nil, &block) # rubocop:disable Metrics/ParameterLists
        headers = add_structured_output_beta_header(headers) if schema
        super
      end

      private

      def add_structured_output_beta_header(headers)
        existing_beta = headers['anthropic-beta']
        new_beta = if existing_beta
                     "#{existing_beta},#{STRUCTURED_OUTPUTS_BETA}"
                   else
                     STRUCTURED_OUTPUTS_BETA
                   end
        headers.merge('anthropic-beta' => new_beta)
      end

      class << self
        def capabilities
          Anthropic::Capabilities
        end

        def configuration_requirements
          %i[anthropic_api_key]
        end
      end
    end
  end
end

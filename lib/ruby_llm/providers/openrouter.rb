# frozen_string_literal: true

module RubyLLM
  module Providers
    # OpenRouter API integration.
    class OpenRouter < OpenAI
      include OpenRouter::Models

      def api_base
        'https://openrouter.ai/api/v1'
      end

      def headers
        {
          'Authorization' => "Bearer #{@config.openrouter_api_key}"
        }
      end

      # OpenRouter doesn't support batch requests yet
      def render_payload_for_batch_request(_messages, tools:, temperature:, model:, params: {}, schema: nil) # rubocop:disable Metrics/ParameterLists
        raise NotImplementedError, 'OpenRouter does not support batch requests. ' \
                                   'Batch request generation is not available for this provider.'
      end

      class << self
        def configuration_requirements
          %i[openrouter_api_key]
        end
      end
    end
  end
end

# frozen_string_literal: true

module RubyLLM
  module Providers
    # DeepSeek API integration.
    class DeepSeek < OpenAI
      include DeepSeek::Chat

      def api_base
        'https://api.deepseek.com'
      end

      def headers
        {
          'Authorization' => "Bearer #{@config.deepseek_api_key}"
        }
      end

      # DeepSeek doesn't support batch requests yet
      def render_payload_for_batch_request(_messages, tools:, temperature:, model:, params: {}, schema: nil) # rubocop:disable Metrics/ParameterLists
        raise NotImplementedError, 'DeepSeek does not support batch requests. ' \
                                   'Batch request generation is not available for this provider.'
      end

      class << self
        def capabilities
          DeepSeek::Capabilities
        end

        def configuration_requirements
          %i[deepseek_api_key]
        end
      end
    end
  end
end

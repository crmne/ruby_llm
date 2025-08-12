# frozen_string_literal: true

module RubyLLM
  module Providers
    # GPUStack API integration based on Ollama.
    class GPUStack < OpenAI
      include GPUStack::Chat
      include GPUStack::Models

      def api_base
        @config.gpustack_api_base
      end

      def headers
        return {} unless @config.gpustack_api_key

        {
          'Authorization' => "Bearer #{@config.gpustack_api_key}"
        }
      end

      # GPUStack doesn't support batch requests yet
      def render_payload_for_batch_request(_messages, tools:, temperature:, model:, params: {}, schema: nil) # rubocop:disable Metrics/ParameterLists
        raise NotImplementedError, 'GPUStack does not support batch requests. ' \
                                   'Batch request generation is not available for this provider.'
      end

      class << self
        def local?
          true
        end

        def configuration_requirements
          %i[gpustack_api_base]
        end
      end
    end
  end
end

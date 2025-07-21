# frozen_string_literal: true

module RubyLLM
  module Providers
    # GPUStack API integration based on Ollama.
    module GPUStack
      extend OpenAI
      extend GPUStack::Chat
      extend GPUStack::Models

      module_function

      def api_base(config)
        config.gpustack_api_base
      end

      def headers(config)
        {
          'Authorization' => "Bearer #{config.gpustack_api_key}"
        }
      end

      def slug
        'gpustack'
      end

      def local?
        true
      end

      def configuration_requirements
        %i[gpustack_api_base gpustack_api_key]
      end
    end
  end
end

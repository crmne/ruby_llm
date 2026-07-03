# frozen_string_literal: true

module RubyLLM
  module Providers
    # GPUStack API integration.
    class GPUStack < Provider
      # GPUStack speaks Ollama's dialect with its own model catalog.
      class ChatCompletions < Ollama::ChatCompletions
        include GPUStack::Models
      end

      protocol :chat_completions, ChatCompletions

      def api_base
        @config.gpustack_api_base
      end

      def headers
        return {} unless @config.gpustack_api_key

        {
          'Authorization' => "Bearer #{@config.gpustack_api_key}"
        }
      end

      class << self
        def configuration_options
          %i[gpustack_api_base gpustack_api_key]
        end

        def configuration_requirements
          %i[gpustack_api_base]
        end

        def local?
          true
        end

        def capabilities
          Ollama::Capabilities
        end
      end
    end
  end
end

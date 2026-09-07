# frozen_string_literal: true

module RubyLLM
  module Providers
    # GPUStack API integration.
    class GPUStack < Provider
      # GPUStack's dialect of the Chat Completions API.
      class ChatCompletions < Protocols::ChatCompletions
        include GPUStack::Chat
        include GPUStack::Embeddings
        include GPUStack::Media
        include GPUStack::Models
        include GPUStack::Speech
        include GPUStack::Transcription
        include Protocols::ChatCompletions::Rerank
        include Protocols::GPUStack::Tokenization
        include Protocols::GPUStack::Videos
      end

      protocol :chat_completions, ChatCompletions
      protocol :responses, Protocols::GPUStack::Responses

      def resolve_protocol(name, model, **request)
        return fetch_protocol(:chat_completions) if !name && request[:operation]

        super
      end

      def api_base
        @config.gpustack_api_base
      end

      def backend_api_base # :nodoc:
        uri = URI(api_base)
        unless uri.path.match?(%r{/model/proxy/\d+/v1/?\z})
          raise Error, 'This GPUStack operation requires gpustack_api_base to end in /model/proxy/ROUTE_ID/v1'
        end

        uri.path = uri.path.sub(%r{/v1/?\z}, '')
        uri.to_s
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
      end
    end
  end
end

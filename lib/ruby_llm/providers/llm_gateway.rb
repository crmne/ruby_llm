# frozen_string_literal: true

module RubyLLM
  module Providers
    # LLMGateway.io API integration.
    class LLMGateway < Provider
      # LLMGateway's dialect of the Chat Completions API.
      class ChatCompletions < Protocols::ChatCompletions
        include LLMGateway::Chat
        include LLMGateway::Images
        include LLMGateway::Models
        include LLMGateway::Streaming
      end

      protocol :chat_completions, ChatCompletions
      files LLMGateway::Files

      def api_base
        @config.llm_gateway_api_base || 'https://api.llmgateway.io/v1'
      end

      def headers
        {
          'Authorization' => "Bearer #{@config.llm_gateway_api_key}"
        }
      end

      def parse_error(response)
        return if response.body.empty?

        body = try_parse_json(response.body)
        case body
        when Hash
          parse_error_part_message body
        when Array
          body.map do |part|
            parse_error_part_message part
          end.join('. ')
        else
          body
        end
      end

      class << self
        def configuration_options
          %i[llm_gateway_api_key llm_gateway_api_base]
        end

        def configuration_requirements
          %i[llm_gateway_api_key]
        end
      end

      private

      def parse_error_part_message(part)
        message = part.dig('error', 'message')
        raw = try_parse_json(part.dig('error', 'metadata', 'raw'))
        return message unless raw.is_a?(Hash)

        raw_message = raw.dig('error', 'message')
        return [message, raw_message].compact.join(' - ') if raw_message

        message
      end
    end
  end
end

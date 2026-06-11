# frozen_string_literal: true

module RubyLLM
  module Providers
    # xAI API integration
    class XAI < Provider
      # xAI's dialect of the Chat Completions API.
      class ChatCompletions < Protocols::ChatCompletions
        include XAI::Chat
        include XAI::Models
      end

      protocol :chat_completions, ChatCompletions

      def api_base
        @config.xai_api_base || 'https://api.x.ai/v1'
      end

      def headers
        {
          'Authorization' => "Bearer #{@config.xai_api_key}",
          'Content-Type' => 'application/json'
        }
      end

      class << self
        def configuration_options
          %i[xai_api_key xai_api_base]
        end

        def configuration_requirements
          %i[xai_api_key]
        end
      end
    end
  end
end

# frozen_string_literal: true

module RubyLLM
  module Providers
    # DeepSeek API integration.
    class DeepSeek < Provider
      # DeepSeek's dialect of the Chat Completions API.
      class ChatCompletions < Protocols::ChatCompletions
        include DeepSeek::Chat
      end

      protocol :chat_completions, ChatCompletions

      def api_base
        @config.deepseek_api_base || 'https://api.deepseek.com'
      end

      def headers
        {
          'Authorization' => "Bearer #{@config.deepseek_api_key}"
        }
      end

      class << self
        def capabilities
          DeepSeek::Capabilities
        end

        def configuration_options
          %i[deepseek_api_key deepseek_api_base]
        end

        def configuration_requirements
          %i[deepseek_api_key]
        end
      end
    end
  end
end

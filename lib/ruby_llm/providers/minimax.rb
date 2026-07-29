# frozen_string_literal: true

module RubyLLM
  module Providers
    # MiniMax API integration. MiniMax exposes an OpenAI-compatible Chat
    # Completions API. Point +minimax_api_base+ at the regional endpoint you
    # use: https://api.minimax.io/v1 (global, the default) or
    # https://api.minimaxi.com/v1 (Mainland China).
    class MiniMax < Provider
      # MiniMax's dialect of the Chat Completions API.
      class ChatCompletions < Protocols::ChatCompletions
        include MiniMax::Chat
        include MiniMax::Models
      end

      protocol :chat_completions, ChatCompletions

      def api_base
        @config.minimax_api_base || 'https://api.minimax.io/v1'
      end

      def headers
        {
          'Authorization' => "Bearer #{@config.minimax_api_key}"
        }
      end

      class << self
        def capabilities
          MiniMax::Capabilities
        end

        def configuration_options
          %i[minimax_api_key minimax_api_base]
        end

        def configuration_requirements
          %i[minimax_api_key]
        end
      end
    end
  end
end

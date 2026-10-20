# frozen_string_literal: true

module RubyLLM
  module Providers
    # Moonshot AI API integration for the Kimi models.
    class Moonshot < Provider
      # Moonshot's dialect of the Chat Completions API.
      class ChatCompletions < Protocols::ChatCompletions
        include Moonshot::Chat
      end

      protocol :chat_completions, ChatCompletions

      def api_base
        @config.moonshot_api_base || 'https://api.moonshot.ai/v1'
      end

      def headers
        { 'Authorization' => "Bearer #{@config.moonshot_api_key}" }
      end

      def account_identity
        account_digest(api_base, @config.moonshot_api_key)
      end

      class << self
        def capabilities
          Moonshot::Capabilities
        end

        def configuration_options
          %i[moonshot_api_key moonshot_api_base]
        end

        def configuration_requirements
          %i[moonshot_api_key]
        end
      end
    end
  end
end

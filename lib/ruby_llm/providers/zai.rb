# frozen_string_literal: true

module RubyLLM
  module Providers
    # Z.ai API integration for Zhipu's GLM models.
    class ZAI < Provider
      # Z.ai's dialect of the Chat Completions API.
      class ChatCompletions < Protocols::ChatCompletions
        include ZAI::Chat
      end

      protocol :chat_completions, ChatCompletions

      def api_base
        configured_api_base(:zai_api_base, 'https://api.z.ai/api/paas/v4', endpoints: Protocols::ChatCompletions::ENDPOINT_PATHS)
      end

      def headers
        { 'Authorization' => "Bearer #{@config.zai_api_key}" }
      end

      def account_identity
        account_digest(api_base, @config.zai_api_key)
      end

      class << self
        def models_dev_provider_ids # :nodoc:
          %w[zai]
        end

        def configuration_options
          %i[zai_api_key zai_api_base]
        end

        def configuration_requirements
          %i[zai_api_key]
        end
      end
    end
  end
end

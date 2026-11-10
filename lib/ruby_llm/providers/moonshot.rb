# frozen_string_literal: true

module RubyLLM
  module Providers
    # Moonshot AI API integration for the Kimi models.
    class Moonshot < Provider
      # Moonshot's dialect of the Chat Completions API.
      class ChatCompletions < Protocols::ChatCompletions
        include Moonshot::Chat
        include Moonshot::Documents
      end

      protocol :chat_completions, ChatCompletions, batches: Protocols::ChatCompletions::Batches
      protocol :responses, Moonshot::Responses
      protocol :files, Protocols::Moonshot::Files

      def api_base
        configured_api_base(:moonshot_api_base, 'https://api.moonshot.ai/v1', endpoints: Protocols::ChatCompletions::ENDPOINT_PATHS)
      end

      def headers
        { 'Authorization' => "Bearer #{@config.moonshot_api_key}" }
      end

      def account_identity
        account_digest(api_base, @config.moonshot_api_key)
      end

      def batch_cost_multiplier(**) = 0.6

      class << self
        def open_telemetry_name # :nodoc:
          'moonshot_ai'
        end

        def models_dev_provider_ids # :nodoc:
          %w[moonshotai]
        end

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

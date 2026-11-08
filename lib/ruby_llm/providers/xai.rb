# frozen_string_literal: true

module RubyLLM
  module Providers
    # xAI API integration
    class XAI < Provider
      protocol :responses, XAI::Responses
      protocol :chat_completions, ChatCompletions, batches: XAI::ChatCompletions::Batches
      protocol :files, Protocols::XAI::Files

      def api_base
        configured_api_base(:xai_api_base, 'https://api.x.ai/v1', endpoints: Protocols::ChatCompletions::ENDPOINT_PATHS)
      end

      def headers
        {
          'Authorization' => "Bearer #{@config.xai_api_key}"
        }
      end

      def account_identity
        account_digest(api_base, @config.xai_api_key)
      end

      class << self
        def open_telemetry_name # :nodoc:
          'x_ai'
        end

        def models_dev_provider_ids # :nodoc:
          %w[xai]
        end

        def capabilities
          XAI::Capabilities
        end

        def configuration_options
          %i[xai_api_key xai_api_base]
        end

        def configuration_requirements
          %i[xai_api_key]
        end
      end

      private

      def batch_protocol
        batch_protocol_for_name(:chat_completions)
      end
    end
  end
end

# frozen_string_literal: true

module RubyLLM
  module Providers
    # Z.ai API integration for Zhipu's GLM models.
    class ZAI < Provider
      # Z.ai's dialect of the Chat Completions API.
      class ChatCompletions < Protocols::ChatCompletions
        include ZAI::Chat
        include ZAI::OCR
        include ZAI::TokenCounting
        include ZAI::Videos

        def server_tool_aliases
          ZAI::Chat::SERVER_TOOL_ALIASES
        end

        private

        def provider_file_references?
          true
        end

        # Z.ai reads a PDF only through its Files API, so any inline PDF is
        # uploaded, not just a large one.
        def default_large_file_upload_threshold
          0
        end

        # Only the GLM-5.3-Flash series accepts a file_id.
        def provider_file_attachable?(attachment)
          attachment.pdf? && ZAI::Chat.reads_files?(@model)
        end
      end

      protocol :chat_completions, ChatCompletions
      protocol :files, Protocols::ZAI::Files

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

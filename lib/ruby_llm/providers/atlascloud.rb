# frozen_string_literal: true

module RubyLLM
  module Providers
    # Atlas Cloud OpenAI-compatible LLM API integration.
    class AtlasCloud < Provider
      # Atlas Cloud speaks the Chat Completions API.
      class ChatCompletions < Protocols::ChatCompletions
        include Protocols::ChatCompletions::Models
      end

      protocol :chat_completions, ChatCompletions

      def api_base
        @config.atlascloud_api_base || 'https://api.atlascloud.ai/v1'
      end

      def headers
        {
          'Authorization' => "Bearer #{@config.atlascloud_api_key}"
        }
      end

      class << self
        def capabilities
          AtlasCloud::Capabilities
        end

        def display_name
          'Atlas Cloud'
        end

        def configuration_options
          %i[atlascloud_api_key atlascloud_api_base]
        end

        def configuration_requirements
          %i[atlascloud_api_key]
        end
      end
    end
  end
end

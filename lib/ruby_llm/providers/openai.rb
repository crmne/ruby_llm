# frozen_string_literal: true

module RubyLLM
  module Providers
    # OpenAI API integration. Handles chat completion, function calling,
    # and OpenAI's unique streaming format. Supports GPT-4, GPT-3.5,
    # and other OpenAI models.
    module OpenAI
      extend Provider
      extend OpenAI::Chat
      extend OpenAI::Embeddings
      extend OpenAI::Models
      extend OpenAI::Streaming
      extend OpenAI::Tools
      extend OpenAI::Images
      extend OpenAI::Media

      def self.extended(base)
        base.extend(Provider)
        base.extend(OpenAI::Chat)
        base.extend(OpenAI::Embeddings)
        base.extend(OpenAI::Models)
        base.extend(OpenAI::Streaming)
        base.extend(OpenAI::Tools)
        base.extend(OpenAI::Images)
        base.extend(OpenAI::Media)
      end

      module_function

      def api_base
        RubyLLM.config.openai_api_base || 'https://api.openai.com/v1'
      end

      def headers
        {
          'Authorization' => "Bearer #{RubyLLM.config.openai_api_key}"
        }
      end

      def capabilities
        OpenAI::Capabilities
      end

      def slug
        'openai'
      end

      def configuration_requirements
        %i[openai_api_key]
      end
    end
  end
end

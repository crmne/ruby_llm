# frozen_string_literal: true

require_relative 'open_router/capabilities'
require_relative 'open_router/chat'
require_relative 'open_router/streaming'
require_relative 'open_router/models'

module RubyLLM
  module Providers
    # OpenRouter API integration. Provides access to multiple LLM providers through a single API.
    # Supports models from various providers including Anthropic, OpenAI, and others.
    # Documentation: https://openrouter.ai/docs
    module OpenRouter
      extend Provider
      extend OpenRouter::Chat
      extend OpenRouter::Streaming
      extend OpenRouter::Models

      def self.extended(base)
        base.extend(Provider)
        base.extend(OpenRouter::Chat)
        base.extend(OpenRouter::Streaming)
        base.extend(OpenRouter::Models)
      end

      module_function

      def api_base
        'https://api.openrouter.ai/api/v1'
      end

      def headers
        {
          'Authorization' => "Bearer #{RubyLLM.config.open_router_api_key}",
          'HTTP-Referer' => 'https://github.com/crmne/ruby_llm',  # Required by OpenRouter
          'X-Title' => 'RubyLLM'  # Required by OpenRouter
        }
      end

      def capabilities
        OpenRouter::Capabilities
      end

      def slug
        'open_router'
      end
    end
  end
end 
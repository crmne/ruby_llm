# frozen_string_literal: true

module RubyLLM
  module Providers
    # Anthropic Claude API integration.
    class Anthropic < Provider
      include Anthropic::Chat
      include Anthropic::Embeddings
      include Anthropic::Media
      include Anthropic::Models
      include Anthropic::Streaming
      include Anthropic::Tools

      def api_base
        'https://api.anthropic.com'
      end

      def headers
        {
          'x-api-key' => @config.anthropic_api_key,
          'anthropic-version' => '2023-06-01'
        }
      end

      # Options for the Anthropic provider
      class Options
        attr_accessor :cache_last_system_prompt, :cache_last_user_prompt, :cache_tools

        def initialize(cache_last_system_prompt: false, cache_last_user_prompt: false, cache_tools: false)
          @cache_last_system_prompt = cache_last_system_prompt
          @cache_last_user_prompt = cache_last_user_prompt
          @cache_tools = cache_tools
        end
      end

      class << self
        def capabilities
          Anthropic::Capabilities
        end

        def options
          Anthropic::Options
        end

        def configuration_requirements
          %i[anthropic_api_key]
        end
      end
    end
  end
end

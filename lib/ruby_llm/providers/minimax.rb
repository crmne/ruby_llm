# frozen_string_literal: true

module RubyLLM
  module Providers
    # MiniMax API integration, through its Anthropic-compatible endpoint.
    class MiniMax < Provider
      protocol :anthropic, MiniMax::Anthropic

      def api_base
        @config.minimax_api_base || 'https://api.minimax.io/anthropic'
      end

      def headers
        { 'Authorization' => "Bearer #{@config.minimax_api_key}" }
      end

      def account_identity
        account_digest(api_base, @config.minimax_api_key)
      end

      class << self
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

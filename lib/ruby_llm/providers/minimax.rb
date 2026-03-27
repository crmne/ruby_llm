# frozen_string_literal: true

module RubyLLM
  module Providers
    # MiniMax API integration.
    # MiniMax provides an OpenAI-compatible chat completions API at https://api.minimax.io/v1
    class MiniMax < OpenAI
      include MiniMax::Chat
      include MiniMax::Models

      def api_base
        @config.minimax_api_base || 'https://api.minimax.io/v1'
      end

      def headers
        {
          'Authorization' => "Bearer #{@config.minimax_api_key}",
          'Content-Type' => 'application/json'
        }
      end

      def maybe_normalize_temperature(temperature, _model)
        MiniMax::Temperature.normalize(temperature)
      end

      class << self
        def capabilities
          MiniMax::Capabilities
        end

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

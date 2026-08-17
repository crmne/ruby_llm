# frozen_string_literal: true

module RubyLLM
  module Providers
    # Direct MiniMax API integration. MiniMax serves one host per region,
    # and its video endpoints are versioned independently of the rest of
    # the API, so video URLs are built per API version.
    class MiniMax < Provider
      DEFAULT_API_BASE = 'https://api.minimax.io/v1'

      class VideoGeneration < Protocol
        include MiniMax::Videos
      end

      protocol :video_generation, VideoGeneration

      def api_base
        @config.minimax_api_base || DEFAULT_API_BASE
      end

      def headers
        { 'Authorization' => "Bearer #{@config.minimax_api_key}" }
      end

      # Video generation lives on /v2 for the newest model and on /v1 for the
      # rest of the catalog, so both versions are rebuilt from the configured
      # host. Pointing minimax_api_base at another region moves every version
      # with it.
      def video_api_base(api_version)
        "#{api_base.sub(%r{/v\d+/?\z}, '')}/#{api_version}"
      end

      class << self
        def assume_models_exist?
          true
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

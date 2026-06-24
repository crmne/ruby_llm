# frozen_string_literal: true

module RubyLLM
  module Providers
    # TwelveLabs API integration.
    #
    # TwelveLabs provides multimodal video understanding (Pegasus) and
    # multimodal embeddings (Marengo). This provider wires up Marengo text
    # embeddings, which return a 512-dimensional float vector and fit RubyLLM's
    # synchronous embedding interface.
    class TwelveLabs < Provider
      protocol :twelvelabs, API

      def api_base
        @config.twelvelabs_api_base || 'https://api.twelvelabs.io/v1.3'
      end

      def headers
        {
          'x-api-key' => @config.twelvelabs_api_key
        }
      end

      class << self
        def capabilities
          TwelveLabs::Capabilities
        end

        def configuration_options
          %i[twelvelabs_api_key twelvelabs_api_base]
        end

        def configuration_requirements
          %i[twelvelabs_api_key]
        end

        # TwelveLabs models are not in the models.dev registry.
        def assume_models_exist?
          true
        end
      end
    end
  end
end

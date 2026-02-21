# frozen_string_literal: true

module RubyLLM
  module Providers
    # ModelsLab API integration.
    class ModelsLab < Provider
      include ModelsLab::Images

      def api_base
        @config.modelslab_api_base || 'https://modelslab.com/api/v6'
      end

      def headers
        {
          'Content-Type' => 'application/json'
        }.compact
      end

      class << self
        def capabilities
          ModelsLab::Capabilities
        end

        def configuration_requirements
          %i[modelslab_api_key]
        end
      end
    end
  end
end

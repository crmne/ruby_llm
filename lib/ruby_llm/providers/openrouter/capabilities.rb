# frozen_string_literal: true

module RubyLLM
  module Providers
    module OpenRouter
      # Determines capabilities and pricing for OpenRouter models
      module Capabilities
        CAPABILITIES_BASE_URL = 'https://openrouter.ai/api/v1/models'

        module_function

        # Determines if the model supports function calling
        # @param model_id [String] the model identifier
        # @return [Boolean] true if the model supports functions
        def supports_functions?(model_id)
          if @models_with_function_support.nil?
            response = client.get('?supported_parameters=tools')
            @models_with_function_support = response.body['data'].map { |model| model['id'] }
          end

          @models_with_function_support.include?(model_id)
        end

        # Determines if the model supports JSON mode
        # @param model_id [String] the model identifier
        # @return [Boolean] true if the model supports JSON mode
        def supports_json_mode?(model_id)
          if @models_with_json_mode_support.nil?
            response = client.get('?supported_parameters=structured_output')
            @models_with_json_mode_support = response.body['data'].map { |model| model['id'] }
          end

          @models_with_json_mode_support.include?(model_id)
        end

        def client
          @client ||= Faraday.new(CAPABILITIES_BASE_URL) do |f|
            f.response :json
          end
        end
      end
    end
  end
end

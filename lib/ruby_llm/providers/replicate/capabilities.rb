# frozen_string_literal: true

module RubyLLM
  module Providers
    class Replicate
      # Determines capabilities for Replicate models
      module Capabilities
        module_function

        def metadata_from(model_data)
          input_schema = model_data.dig('latest_version', 'openapi_schema', 'components', 'schemas', 'Input')

          {
            url: model_data['url'],
            description: model_data['description'],
            license_url: model_data['license_url'],
            is_official: model_data['is_official'],
            supported_parameters: input_schema['properties'].keys - ['prompt'],
            latest_version_created_at: model_data.dig('latest_version', 'created_at')
          }
        end
      end
    end
  end
end

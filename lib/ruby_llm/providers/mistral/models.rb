# frozen_string_literal: true

module RubyLLM
  module Providers
    module Mistral
      # Model information for Mistral
      module Models
        module_function

        def models_url
          'models'
        end

        def headers(config)
          {
            'Authorization' => "Bearer #{config.mistral_api_key}"
          }
        end
      end
    end
  end
end

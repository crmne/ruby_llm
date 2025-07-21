# frozen_string_literal: true

module RubyLLM
  module Providers
    module GPUStack
      # Models methods of the GPUStack API integration
      module Models
        module_function

        def models_url
          'models'
        end

        def parse_list_models_response(response, slug, _capabilities)
          items = response.body['items'] || []
          items.map do |model|
            Model::Info.new(
              id: model['name'],
              created_at: model['created_at'] ? Time.parse(model['created_at']) : nil,
              display_name: "#{model['source']}/#{model['name']}",
              provider: slug,
              type: determine_model_type(model),
              metadata: {
                description: model['description'],
                source: model['source'],
                huggingface_repo_id: model['huggingface_repo_id'],
                ollama_library_model_name: model['ollama_library_model_name'],
                backend: model['backend'],
                meta: model['meta'],
                categories: model['categories']
              },
              context_window: model.dig('meta', 'n_ctx'),
              # Using context window as max tokens since it's not explicitly provided
              max_tokens: model.dig('meta', 'n_ctx'),
              supports_vision: model.dig('meta', 'support_vision') || false,
              supports_functions: model.dig('meta', 'support_tool_calls') || false,
              supports_json_mode: true, # Assuming all models support JSON mode
              input_price_per_million: 0.0,  # Price information not available in new format
              output_price_per_million: 0.0  # Price information not available in new format
            )
          end
        end

        private

        def determine_model_type(model)
          return 'embedding' if model['categories']&.include?('embedding')
          return 'chat' if model['categories']&.include?('llm')

          'other'
        end
      end
    end
  end
end

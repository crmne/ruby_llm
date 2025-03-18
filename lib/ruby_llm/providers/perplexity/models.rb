# frozen_string_literal: true

module RubyLLM
  module Providers
    module Perplexity
      # Models methods of the Perplexity API integration
      module Models
        module_function

        def models_url
          # Perplexity doesn't have a models endpoint, so we'll return a static list
          nil
        end

        def parse_list_models_response(_response, slug, capabilities)
          # Since Perplexity doesn't have a models endpoint, we'll return a static list
          [
            create_model_info('sonar', slug, capabilities),
            create_model_info('sonar-pro', slug, capabilities),
            create_model_info('sonar-reasoning', slug, capabilities),
            create_model_info('sonar-reasoning-pro', slug, capabilities),
            create_model_info('sonar-deep-research', slug, capabilities),
            create_model_info('r1-1776', slug, capabilities)
          ]
        end

        def create_model_info(id, slug, capabilities)
          ModelInfo.new(
            id: id,
            created_at: Time.now,
            display_name: capabilities.format_display_name(id),
            provider: slug,
            type: capabilities.model_type(id),
            family: capabilities.model_family(id).to_s,
            context_window: capabilities.context_window_for(id),
            max_tokens: capabilities.max_tokens_for(id),
            supports_vision: capabilities.supports_vision?(id),
            supports_functions: capabilities.supports_functions?(id),
            supports_json_mode: capabilities.supports_json_mode?(id),
            input_price_per_million: capabilities.input_price_for(id),
            output_price_per_million: capabilities.output_price_for(id),
            metadata: {
              reasoning_price_per_million: capabilities.reasoning_price_for(id)
            }
          )
        end
      end
    end
  end
end

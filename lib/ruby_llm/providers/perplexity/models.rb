# frozen_string_literal: true

module RubyLLM
  module Providers
    class Perplexity
      # Models methods of the Perplexity API integration
      module Models
        MODEL_IDS = %w[
          sonar
          sonar-pro
          sonar-reasoning
          sonar-reasoning-pro
          sonar-deep-research
        ].freeze

        def list_models(**)
          slug = 'perplexity'
          parse_list_models_response(nil, slug, Perplexity::Capabilities)
        end

        def parse_list_models_response(_response, slug, capabilities)
          MODEL_IDS.map { |id| create_model_info(id, slug, capabilities) }
        end

        def create_model_info(id, slug, capabilities)
          Model::Info.new(
            id: id,
            name: id,
            provider: slug,
            context_window: capabilities.context_window_for(id),
            max_output_tokens: capabilities.max_tokens_for(id),
            capabilities: capabilities.critical_capabilities_for(id),
            pricing: capabilities.pricing_for(id),
            metadata: {}
          )
        end
      end
    end
  end
end

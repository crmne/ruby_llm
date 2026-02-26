# frozen_string_literal: true

module RubyLLM
  module Providers
    class VoyageAI
      # Models methods for the Voyage AI API integration
      module Models
        def list_models(**)
          slug = 'voyage'
          capabilities = VoyageAI::Capabilities

          capabilities.model_ids.map do |model_id|
            create_model_info(model_id, slug, capabilities)
          end
        end

        def create_model_info(model_id, slug, capabilities)
          release_date = capabilities.release_date_for(model_id)
          created_at = release_date ? Time.parse(release_date) : nil

          Model::Info.new(
            id: model_id,
            name: capabilities.format_display_name(model_id),
            provider: slug,
            family: capabilities.model_family(model_id),
            created_at: created_at,
            context_window: capabilities.context_window_for(model_id),
            max_output_tokens: capabilities.max_tokens_for(model_id),
            modalities: capabilities.modalities_for(model_id),
            capabilities: capabilities.capabilities_for(model_id),
            pricing: capabilities.pricing_for(model_id),
            metadata: {
              object: 'model',
              owned_by: 'voyage'
            }.merge(capabilities.metadata_for(model_id))
          )
        end
      end
    end
  end
end

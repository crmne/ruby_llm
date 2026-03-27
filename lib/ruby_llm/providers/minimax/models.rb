# frozen_string_literal: true

module RubyLLM
  module Providers
    class MiniMax
      # Models methods of the MiniMax API integration.
      # MiniMax does not provide a /v1/models endpoint,
      # so models are statically defined.
      module Models
        def list_models(**)
          slug = 'minimax'
          capabilities = MiniMax::Capabilities
          parse_list_models_response(nil, slug, capabilities)
        end

        def parse_list_models_response(_response, slug, capabilities)
          model_ids.map do |model_id|
            create_model_info(model_id, slug, capabilities)
          end
        end

        def model_ids
          %w[
            MiniMax-M2.7
            MiniMax-M2.7-highspeed
            MiniMax-M2.5
            MiniMax-M2.5-highspeed
          ]
        end

        def create_model_info(model_id, slug, capabilities)
          Model::Info.new(
            id: model_id,
            name: capabilities.format_display_name(model_id),
            provider: slug,
            family: capabilities.model_family(model_id).to_s,
            created_at: Time.now,
            context_window: capabilities.context_window_for(model_id),
            max_output_tokens: capabilities.max_tokens_for(model_id),
            modalities: capabilities.modalities_for(model_id),
            capabilities: capabilities.capabilities_for(model_id),
            pricing: capabilities.pricing_for(model_id),
            metadata: {}
          )
        end
      end
    end
  end
end

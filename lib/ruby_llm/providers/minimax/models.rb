# frozen_string_literal: true

module RubyLLM
  module Providers
    class MiniMax
      # Models methods of the MiniMax API integration. MiniMax has no public
      # model listing endpoint, so the supported models are curated here.
      module Models
        MODEL_IDS = %w[
          MiniMax-M3
          MiniMax-M2.7
        ].freeze

        MODALITIES = {
          'MiniMax-M3' => { input: %w[text image video], output: %w[text] },
          'MiniMax-M2.7' => { input: %w[text], output: %w[text] }
        }.freeze

        def list_models(**)
          slug = 'minimax'
          parse_list_models_response(nil, slug, MiniMax::Capabilities)
        end

        def parse_list_models_response(_response, slug, capabilities)
          MODEL_IDS.map { |id| create_model_info(id, slug, capabilities) }
        end

        def create_model_info(id, slug, capabilities)
          Model.new(
            id: id,
            name: id,
            provider: slug,
            family: 'minimax',
            context_window: capabilities.context_window_for(id),
            max_output_tokens: capabilities.max_tokens_for(id),
            modalities: MODALITIES.fetch(id, input: %w[text], output: %w[text]),
            capabilities: capabilities.critical_capabilities_for(id),
            pricing: capabilities.pricing_for(id),
            metadata: {}
          )
        end
      end
    end
  end
end

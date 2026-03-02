# frozen_string_literal: true

module RubyLLM
  module Providers
    class XAI
      # Models metadata for xAI list models.
      module Models
        module_function

        IMAGE_MODELS = %w[grok-2-image-1212].freeze
        VISION_MODELS = %w[
          grok-2-vision-1212
          grok-4-0709
          grok-4-fast-non-reasoning
          grok-4-fast-reasoning
          grok-4-1-fast-non-reasoning
          grok-4-1-fast-reasoning
        ].freeze
        REASONING_MODELS = %w[
          grok-3-mini
          grok-4-0709
          grok-4-fast-reasoning
          grok-4-1-fast-reasoning
          grok-code-fast-1
        ].freeze

        def parse_list_models_response(response, slug, _capabilities)
          Array(response.body['data']).map do |model_data|
            model_id = model_data['id']

            Model::Info.new(
              id: model_id,
              name: format_display_name(model_id),
              provider: slug,
              family: 'grok',
              created_at: model_data['created'] ? Time.at(model_data['created']) : nil,
              context_window: nil,
              max_output_tokens: nil,
              modalities: modalities_for(model_id),
              capabilities: capabilities_for(model_id),
              pricing: {},
              metadata: {
                object: model_data['object'],
                owned_by: model_data['owned_by']
              }.compact
            )
          end
        end

        def modalities_for(model_id)
          if IMAGE_MODELS.include?(model_id)
            { input: ['text'], output: ['image'] }
          else
            input = ['text']
            input << 'image' if VISION_MODELS.include?(model_id)
            { input: input, output: ['text'] }
          end
        end

        def capabilities_for(model_id)
          return [] if IMAGE_MODELS.include?(model_id)

          capabilities = %w[streaming function_calling structured_output]
          capabilities << 'reasoning' if REASONING_MODELS.include?(model_id)
          capabilities << 'vision' if VISION_MODELS.include?(model_id)
          capabilities
        end

        def format_display_name(model_id)
          model_id.tr('-', ' ').split.map(&:capitalize).join(' ')
        end
      end
    end
  end
end

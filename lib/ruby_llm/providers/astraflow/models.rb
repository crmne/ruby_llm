# frozen_string_literal: true

module RubyLLM
  module Providers
    class Astraflow
      # Models metadata for Astraflow.
      # Astraflow aggregates 200+ models; we parse the provider's /v1/models response
      # dynamically rather than maintaining a hard-coded list.
      module Models
        module_function

        def parse_list_models_response(response, slug, _capabilities)
          Array(response.body['data']).map do |model_data|
            model_id = model_data['id']

            Model::Info.new(
              id: model_id,
              name: format_display_name(model_id),
              provider: slug,
              family: infer_family(model_id),
              created_at: model_data['created'] ? Time.at(model_data['created']) : nil,
              context_window: nil,
              max_output_tokens: nil,
              modalities: { input: ['text'], output: ['text'] },
              capabilities: %w[streaming function_calling],
              pricing: {},
              metadata: {
                object: model_data['object'],
                owned_by: model_data['owned_by']
              }.compact
            )
          end
        end

        def format_display_name(model_id)
          model_id.tr('-', ' ').split.map(&:capitalize).join(' ')
        end

        def infer_family(model_id)
          case model_id
          when /\Agpt/i      then 'gpt'
          when /\Aclaude/i   then 'claude'
          when /\Agemini/i   then 'gemini'
          when /\Amistral/i  then 'mistral'
          when /\Adeepseek/i then 'deepseek'
          when /\Allama/i    then 'llama'
          when /\Aqwen/i     then 'qwen'
          else 'unknown'
          end
        end
      end
    end
  end
end

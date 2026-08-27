# frozen_string_literal: true

module RubyLLM
  module Providers
    class OpenRouter
      # Models methods of the OpenRouter API integration. Chat models come
      # from the main catalog; embedding, speech, transcription, and image
      # models live in separate catalogs that are merged in.
      module Models
        CATALOG_URLS = [
          'models',
          'embeddings/models',
          'models?output_modalities=speech',
          'models?output_modalities=transcription',
          'models?output_modalities=rerank',
          'images/models'
        ].freeze

        OUTPUT_MODALITY_MAP = {
          'speech' => 'audio',
          'transcription' => 'text'
        }.freeze

        CAPABILITY_BY_OUTPUT_MODALITY = {
          'speech' => 'speech_generation',
          'transcription' => 'transcription',
          'image' => 'image_generation'
        }.freeze

        def list_models
          CATALOG_URLS.flat_map do |url|
            parse_list_models_response @connection.get(url), @provider.slug
          end.uniq(&:id)
        end

        module_function

        def models_url
          'models'
        end

        def parse_list_models_response(response, slug)
          Array(response.body['data']).map do |model_data| # rubocop:disable Metrics/BlockLength
            output_modalities = Array(model_data.dig('architecture', 'output_modalities'))
            modalities = {
              input: Array(model_data.dig('architecture', 'input_modalities')),
              output: output_modalities.map { |modality| OUTPUT_MODALITY_MAP.fetch(modality, modality) }.uniq
            }

            pricing = { text_tokens: { standard: {} } }

            pricing_types = {
              prompt: :input_per_million,
              completion: :output_per_million,
              input_cache_read: :cache_read_input_per_million,
              input_cache_write: :cache_write_input_per_million,
              internal_reasoning: :reasoning_output_per_million
            }

            pricing_types.each do |source_key, target_key|
              value = model_data.dig('pricing', source_key.to_s).to_f
              pricing[:text_tokens][:standard][target_key] = value * 1_000_000 if value.positive?
            end

            capabilities = supported_parameters_to_capabilities(model_data['supported_parameters']) |
                           output_modalities.filter_map { |modality| CAPABILITY_BY_OUTPUT_MODALITY[modality] }

            Model.new(
              id: model_data['id'],
              name: model_data['name'],
              provider: slug,
              family: model_data['id'].split('/').first,
              created_at: model_data['created'] ? Time.at(model_data['created']) : nil,
              context_window: model_data['context_length'],
              max_output_tokens: model_data.dig('top_provider', 'max_completion_tokens'),
              knowledge_cutoff: model_data['knowledge_cutoff'],
              modalities: modalities,
              capabilities: capabilities,
              pricing: pricing,
              metadata: {
                description: model_data['description'],
                architecture: model_data['architecture'],
                top_provider: model_data['top_provider'],
                per_request_limits: model_data['per_request_limits'],
                supported_parameters: model_data['supported_parameters'],
                expiration_date: model_data['expiration_date']
              }
            )
          end
        end

        def supported_parameters_to_capabilities(params)
          return [] unless params

          capabilities = []
          capabilities << 'streaming'
          capabilities << 'function_calling' if params.include?('tools') || params.include?('tool_choice')
          capabilities << 'structured_output' if params.include?('response_format')
          capabilities << 'batch' if params.include?('batch')
          capabilities << 'predicted_outputs' if params.include?('logit_bias') && params.include?('top_k')
          capabilities
        end
      end
    end
  end
end

# frozen_string_literal: true

module RubyLLM
  module Providers
    class VertexAI
      # Models methods for the Vertex AI integration
      module Models
        # Gemini and other Google models that aren't returned by the API
        KNOWN_GOOGLE_MODELS = %w[
          gemini-2.5-flash-lite
          gemini-2.5-pro
          gemini-2.5-flash
          gemini-2.0-flash-lite-001
          gemini-2.0-flash-001
          gemini-2.0-flash
          gemini-2.0-flash-exp
          gemini-1.5-pro-002
          gemini-1.5-pro
          gemini-1.5-flash-002
          gemini-1.5-flash
          gemini-1.5-flash-8b
          gemini-pro
          gemini-pro-vision
          gemini-exp-1206
          gemini-exp-1121
          gemini-embedding-001
          text-embedding-005
          text-embedding-004
          text-multilingual-embedding-002
          multimodalembedding
        ].freeze

        def list_models
          all_models = []
          page_token = nil

          all_models.concat(build_known_models)

          loop do
            response = @connection.get('publishers/google/models') do |req|
              req.headers['x-goog-user-project'] = @config.vertexai_project_id
              req.params = { pageSize: 100 }
              req.params[:pageToken] = page_token if page_token
            end

            publisher_models = response.body['publisherModels'] || []
            publisher_models.each do |model_data|
              next if model_data['launchStage'] == 'DEPRECATED'

              model_id = extract_model_id_from_path(model_data['name'])
              all_models << build_model_from_api_data(model_data, model_id)
            end

            page_token = response.body['nextPageToken']
            break unless page_token
          end

          all_models
        rescue StandardError => e
          RubyLLM.logger.debug "Error fetching Vertex AI models: #{e.message}"
          build_known_models
        end

        private

        def build_known_models
          KNOWN_GOOGLE_MODELS.map do |model_id|
            Model::Info.new(
              id: model_id,
              name: model_id,
              provider: slug,
              family: determine_model_family(model_id),
              created_at: nil,
              context_window: Capabilities.context_window_for(model_id),
              max_output_tokens: Capabilities.max_tokens_for(model_id),
              modalities: Capabilities.modalities_for(model_id),
              capabilities: Capabilities.capabilities_for(model_id),
              pricing: Capabilities.pricing_for(model_id),
              metadata: Capabilities.determine_metadata(model_id)
            )
          end
        end

        def build_model_from_api_data(model_data, model_id)
          Model::Info.new(
            id: model_id,
            name: model_id,
            provider: slug,
            family: determine_model_family(model_id),
            created_at: nil,
            context_window: nil,
            max_output_tokens: nil,
            modalities: nil,
            capabilities: extract_capabilities(model_data),
            pricing: nil,
            metadata: {
              version_id: model_data['versionId'],
              open_source_category: model_data['openSourceCategory'],
              launch_stage: model_data['launchStage'],
              supported_actions: model_data['supportedActions'],
              publisher_model_template: model_data['publisherModelTemplate']
            }
          )
        end

        def extract_model_id_from_path(path)
          path.split('/').last
        end

        def determine_model_family(model_id)
          case model_id
          when /^gemini-2\.\d+/ then 'gemini-2'
          when /^gemini-1\.\d+/ then 'gemini-1.5'
          when /^text-embedding/ then 'text-embedding'
          when /bison/ then 'palm'
          when /multimodalembedding/ then 'multimodalembedding'
          else 'gemini'
          end
        end

        def extract_capabilities(model_data)
          capabilities = ['streaming']
          model_name = model_data['name']
          capabilities << 'function_calling' if model_name.include?('gemini')
          capabilities.uniq
        end
      end
    end
  end
end

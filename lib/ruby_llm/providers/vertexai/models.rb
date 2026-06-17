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
        ].freeze

        # Every publisher with models Vertex AI serves as a service. The rest
        # of the Model Garden is deploy-it-yourself and not callable directly.
        PUBLISHERS = %w[google anthropic mistralai meta deepseek-ai qwen openai moonshotai zai-org].freeze

        def list_models
          build_known_models + PUBLISHERS.flat_map { |publisher| publisher_models(publisher) }
        end

        private

        def publisher_models(publisher)
          catalog(publisher).filter_map { |model_data| build_publisher_model(publisher, model_data) }
        end

        # MaaS models are called as publisher/name through the OpenAI-compatible
        # endpoint; directly served models by their bare catalog name.
        def build_publisher_model(publisher, model_data)
          name = model_data['name'].split('/').last
          return if deployable?(model_data)

          if name.end_with?('-maas')
            build_model_from_api_data(model_data, "#{publisher}/#{name}")
          elsif served_directly?(publisher, name)
            build_model_from_api_data(model_data, name)
          end
        end

        # Deploy-it-yourself Model Garden cards expose deploy actions; managed
        # services Vertex AI serves on our behalf never do.
        def deployable?(model_data)
          actions = model_data['supportedActions'] || {}
          actions.key?('deploy') || actions.key?('multiDeployVertex') || actions.key?('deployGke')
        end

        # Among the managed models, which publishers we route by bare name, and
        # for Google (whose catalog is a grab-bag of vision, media, and AutoML
        # products) which of those names are chat or embedding models.
        def served_directly?(publisher, name)
          case publisher
          when 'google' then name.match?(/\Agemini|embedding/)
          when 'anthropic' then true
          when 'mistralai' then VertexAI::Mistral::MODELS.match?(name)
          else false
          end
        end

        def catalog(publisher)
          models = []
          page_token = nil

          loop do
            response = @connection.get("publishers/#{publisher}/models") do |req|
              req.headers['x-goog-user-project'] = @config.vertexai_project_id
              req.params = { pageSize: 100 }
              req.params[:pageToken] = page_token if page_token
            end

            models.concat(response.body['publisherModels'] || [])
            page_token = response.body['nextPageToken']
            break unless page_token
          end

          models.reject { |model_data| model_data['launchStage'] == 'DEPRECATED' }
        rescue StandardError => e
          RubyLLM.logger.debug { "Error fetching Vertex AI #{publisher} models: #{e.message}" }
          []
        end

        def build_known_models
          KNOWN_GOOGLE_MODELS.map do |model_id|
            Model::Info.new(
              id: model_id,
              name: model_id,
              provider: @provider.slug,
              family: determine_model_family(model_id),
              created_at: nil,
              context_window: nil,
              max_output_tokens: nil,
              modalities: nil,
              capabilities: %w[streaming function_calling],
              pricing: nil,
              metadata: {
                source: 'known_models'
              }
            )
          end
        end

        def build_model_from_api_data(model_data, model_id)
          Model::Info.new(
            id: model_id,
            name: model_id,
            provider: @provider.slug,
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

        def determine_model_family(model_id)
          case model_id
          when /^claude.*haiku/ then 'claude-haiku'
          when /^claude.*sonnet/ then 'claude-sonnet'
          when /^claude.*opus/ then 'claude-opus'
          when /^claude/ then 'claude'
          when %r{^meta/} then 'llama'
          when %r{^deepseek-ai/} then 'deepseek'
          when %r{^qwen/} then 'qwen'
          when %r{^moonshotai/} then 'kimi'
          when %r{^zai-org/} then 'glm'
          when %r{^openai/} then 'gpt-oss'
          when %r{^google/} then 'gemma'
          when /^codestral/ then 'codestral'
          when /^mi(ni)?stral/ then 'mistral'
          when /^gemini-2\.\d+/ then 'gemini-2'
          when /^gemini-1\.\d+/ then 'gemini-1.5'
          when /^text-embedding/ then 'text-embedding'
          when /bison/ then 'palm'
          else 'gemini'
          end
        end

        def extract_capabilities(model_data)
          model_data['name'].match?(/ocr|embedding/) ? %w[streaming] : %w[streaming function_calling]
        end
      end
    end
  end
end

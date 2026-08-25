# frozen_string_literal: true

module RubyLLM
  module Providers
    class VertexAI
      # Models methods for the Vertex AI integration
      module Models
        # Google models the publisher catalog omits in some regions while still
        # serving them there. Every id must be callable in at least one region;
        # ids that answer nowhere do not belong here.
        KNOWN_GOOGLE_MODELS = %w[
          gemini-2.5-flash-lite
          gemini-2.5-pro
          gemini-2.5-flash
          gemini-2.0-flash-lite-001
          gemini-2.0-flash-001
          gemini-1.5-pro-002
          gemini-1.5-pro
          gemini-pro
          gemini-pro-vision
          gemini-embedding-001
          text-embedding-005
          text-embedding-004
          text-multilingual-embedding-002
        ].freeze

        # Every publisher with models Vertex AI serves as a service. The rest
        # of the Model Garden is deploy-it-yourself and not callable directly.
        PUBLISHERS = %w[google anthropic mistralai meta deepseek-ai qwen openai moonshotai zai-org].freeze

        # Vertex AI serves a different slice of the catalog in each location and
        # neither of these is a superset of the other, so a listing unions them.
        CATALOG_LOCATIONS = %w[global us-central1].freeze

        # The configured location has to answer: without it we would report a
        # catalog the caller cannot reach. A supplementary location is a bonus,
        # so a failure there is a warning and the rest of the union stands.
        def list_models
          fetched = []
          counts = {}

          catalog_connections.each do |location, connection|
            models = location_models(connection)
            counts[location] = models.size
            fetched.concat(models)
          rescue StandardError => e
            raise if location == configured_location

            RubyLLM.logger.warn "Skipping the Vertex AI catalog at #{location}: #{e.class}: #{e.message}"
          end

          models = fetched.uniq(&:id)
          log_catalog(counts, models)

          models + build_known_models(models.map(&:id))
        end

        private

        def configured_location
          @config.vertexai_location.to_s
        end

        # The location lives in the host, so locations sharing one api base,
        # as they do behind a custom vertexai_api_base, are one catalog.
        def catalog_connections
          [configured_location, *CATALOG_LOCATIONS]
            .uniq { |location| @provider.api_base_for(location) }
            .to_h { |location| [location, connection_for(location)] }
        end

        def connection_for(location)
          return @connection if location == configured_location

          Connection.new(@provider, @config, api_base: @provider.api_base_for(location))
        end

        def log_catalog(counts, models)
          per_location = counts.map { |location, count| "#{location} (#{count})" }.join(', ')
          RubyLLM.logger.info "Fetched the Vertex AI catalog from #{per_location}: #{models.size} models"
        end

        # A publisher with nothing to offer in a region answers 200 with an
        # empty list, so any error here is infrastructure, not an empty
        # catalog. Reporting a partial catalog as a success would drop the
        # missing publishers from the registry.
        def location_models(connection)
          failures = []
          models = PUBLISHERS.flat_map do |publisher|
            publisher_models(publisher, connection)
          rescue StandardError => e
            failures << "#{publisher} (#{e.class}: #{e.message})"
            []
          end

          raise Error, "Could not fetch the Vertex AI catalog for #{failures.join(', ')}" if failures.any?

          models
        end

        def publisher_models(publisher, connection)
          catalog(publisher, connection).filter_map { |model_data| build_publisher_model(publisher, model_data) }
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

        def catalog(publisher, connection)
          models = []
          page_token = nil

          loop do
            response = connection.get("publishers/#{publisher}/models") do |req|
              req.headers['x-goog-user-project'] = @config.vertexai_project_id
              req.params = { pageSize: 100 }
              req.params[:pageToken] = page_token if page_token
            end

            models.concat(response.body['publisherModels'] || [])
            page_token = response.body['nextPageToken']
            break unless page_token
          end

          models.reject { |model_data| model_data['launchStage'] == 'DEPRECATED' }
        end

        def build_known_models(fetched_ids)
          (KNOWN_GOOGLE_MODELS - fetched_ids).map do |model_id|
            Model.new(
              id: model_id,
              name: model_id,
              provider: @provider.slug,
              family: determine_model_family(model_id),
              created_at: nil,
              context_window: nil,
              max_output_tokens: nil,
              modalities: nil,
              capabilities: extract_capabilities(model_id),
              pricing: nil,
              metadata: {
                source: 'known_models'
              }
            )
          end
        end

        def build_model_from_api_data(model_data, model_id)
          Model.new(
            id: model_id,
            name: model_id,
            provider: @provider.slug,
            family: determine_model_family(model_id),
            created_at: nil,
            context_window: nil,
            max_output_tokens: nil,
            modalities: nil,
            capabilities: extract_capabilities(model_data['name']),
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

        def extract_capabilities(name)
          name.match?(/ocr|embedding/) ? %w[streaming] : %w[streaming function_calling]
        end
      end
    end
  end
end

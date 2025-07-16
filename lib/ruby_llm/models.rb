# frozen_string_literal: true

module RubyLLM
  # Registry of available AI models and their capabilities. Provides a clean interface
  # to discover and work with models from different providers.
  #
  # Example:
  #   RubyLLM.models.all                                  # All available models
  #   RubyLLM.models.chat_models                          # Models that support chat
  #   RubyLLM.models.by_provider('openai').chat_models    # OpenAI chat models
  #   RubyLLM.models.find('claude-3')                     # Get info about a specific model
  class Models
    include Enumerable

    class << self
      def instance
        @instance ||= new
      end

      def provider_for(model)
        Provider.for(model)
      end

      def models_file
        File.expand_path('models.json', __dir__)
      end

      def refresh!
        # Collect models from both sources
        provider_models = fetch_from_providers
        parsera_models = fetch_from_parsera

        # Merge with parsera data taking precedence
        merged_models = merge_models(provider_models, parsera_models)

        @instance = new(merged_models)
      end

      def fetch_from_providers
        configured = Provider.configured_providers(RubyLLM.config).filter(&:remote?)

        RubyLLM.logger.info "Fetching models from providers: #{configured.map(&:slug).join(', ')}"

        configured.flat_map do |provider|
          provider.list_models(connection: provider.connection(RubyLLM.config))
        end
      end

      def resolve(model_id, provider: nil, assume_exists: false) # rubocop:disable Metrics/PerceivedComplexity
        assume_exists = true if provider && Provider.providers[provider.to_sym].local?

        if assume_exists
          raise ArgumentError, 'Provider must be specified if assume_exists is true' unless provider

          provider = Provider.providers[provider.to_sym] || raise(Error, "Unknown provider: #{provider.to_sym}")
          model = Model::Info.new(
            id: model_id,
            name: model_id.gsub('-', ' ').capitalize,
            provider: provider.slug,
            capabilities: %w[function_calling streaming],
            modalities: { input: %w[text image], output: %w[text] },
            metadata: { warning: 'Assuming model exists, capabilities may not be accurate' }
          )
          if RubyLLM.config.log_assume_model_exists
            RubyLLM.logger.warn "Assuming model '#{model_id}' exists for provider '#{provider}'. " \
                                'Capabilities may not be accurately reflected.'
          end
        else
          model = Models.find model_id, provider
          provider = Provider.providers[model.provider.to_sym] || raise(Error, "Unknown provider: #{model.provider}")
        end
        [model, provider]
      end

      def method_missing(method, ...)
        if instance.respond_to?(method)
          instance.send(method, ...)
        else
          super
        end
      end

      def respond_to_missing?(method, include_private = false)
        instance.respond_to?(method, include_private) || super
      end

      def fetch_from_parsera
        RubyLLM.logger.info 'Fetching models from Parsera API...'

        connection = Connection.basic do |f|
          f.request :json
          f.response :json, parser_options: { symbolize_names: true }
        end
        response = connection.get 'https://api.parsera.org/v1/llm-specs'
        models = response.body.map { |data| Model::Info.new(data) }
        models.reject { |model| model.provider.nil? || model.id.nil? }
      end

      def merge_models(provider_models, parsera_models)
        # Create lookups for both sets of models
        parsera_by_key = index_by_key(parsera_models)
        provider_by_key = index_by_key(provider_models)

        # All keys from both sources
        all_keys = parsera_by_key.keys | provider_by_key.keys

        # Merge data, with parsera taking precedence
        models = all_keys.map do |key|
          if (parsera_model = parsera_by_key[key])
            # Parsera has this model - use it as the base
            if (provider_model = provider_by_key[key])
              # Both sources have this model, add provider metadata
              add_provider_metadata(parsera_model, provider_model)
            else
              # Only parsera has this model
              parsera_model
            end
          else
            # Only provider has this model
            provider_by_key[key]
          end
        end

        models.sort_by { |m| [m.provider, m.id] }
      end

      def index_by_key(models)
        models.each_with_object({}) do |model, hash|
          hash["#{model.provider}:#{model.id}"] = model
        end
      end

      def add_provider_metadata(parsera_model, provider_model)
        # Create a new Model::Info with parsera data but include provider metadata
        data = parsera_model.to_h
        data[:metadata] = provider_model.metadata.merge(data[:metadata] || {})
        Model::Info.new(data)
      end
    end

    # Initialize with optional pre-filtered models
    def initialize(models = nil)
      @models = models || load_models
    end

    # Load models from the JSON file
    def load_models
      data = File.exist?(self.class.models_file) ? File.read(self.class.models_file) : '[]'
      JSON.parse(data, symbolize_names: true).map { |model| Model::Info.new(model) }
    rescue JSON::ParserError
      []
    end

    def save_models
      File.write(self.class.models_file, JSON.pretty_generate(all.map(&:to_h)))
    end

    # Return all models in the collection
    def all
      @models
    end

    # Allow enumeration over all models
    def each(&)
      all.each(&)
    end

    # Find a specific model by ID
    def find(model_id, provider = nil)
      if provider
        find_with_provider(model_id, provider)
      else
        find_without_provider(model_id)
      end
    end

    # Filter to only chat models
    def chat_models
      self.class.new(all.select { |m| m.type == 'chat' })
    end

    # Filter to only embedding models
    def embedding_models
      self.class.new(all.select { |m| m.type == 'embedding' })
    end

    # Filter to only audio models
    def audio_models
      self.class.new(all.select { |m| m.type == 'audio' })
    end

    # Filter to only image models
    def image_models
      self.class.new(all.select { |m| m.type == 'image' })
    end

    # Filter models by family
    def by_family(family)
      self.class.new(all.select { |m| m.family == family.to_s })
    end

    # Filter models by provider
    def by_provider(provider)
      self.class.new(all.select { |m| m.provider == provider.to_s })
    end

    # Instance method to refresh models
    def refresh!
      self.class.refresh!
    end

    private

    def find_with_provider(model_id, provider)
      resolved_id = Aliases.resolve(model_id, provider)
      all.find { |m| m.id == model_id && m.provider == provider.to_s } ||
        all.find { |m| m.id == resolved_id && m.provider == provider.to_s } ||
        raise(ModelNotFoundError, "Unknown model: #{model_id} for provider: #{provider}")
    end

    def find_without_provider(model_id)
      all.find { |m| m.id == model_id } ||
        all.find { |m| m.id == Aliases.resolve(model_id) } ||
        raise(ModelNotFoundError, "Unknown model: #{model_id}")
    end
  end
end

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
  class Models # rubocop:disable Metrics/ClassLength
    include Enumerable

    # Delegate class methods to the singleton instance
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
        @instance = new(fetch_models)
        RubyLLM.logger.info "Model registry refreshed with #{@instance.count} models."
        @instance
      end

      def resolve(model_id, provider: nil, assume_exists: false) # rubocop:disable Metrics/AbcSize,Metrics/MethodLength
        assume_exists = true if provider && Provider.providers[provider.to_sym].local?

        if assume_exists
          raise ArgumentError, 'Provider must be specified if assume_exists is true' unless provider

          provider = Provider.providers[provider.to_sym] || raise(Error, "Unknown provider: #{provider.to_sym}")
          model = Struct.new(:id, :provider, :supports_functions, :supports_vision).new(model_id, provider, true, true)
          RubyLLM.logger.warn "Assuming model '#{model_id}' exists for provider '#{provider}'. " \
                              'Capabilities may not be accurately reflected.'
        else
          model = Models.find model_id, provider
          provider = Provider.providers[model.provider.to_sym] || raise(Error, "Unknown provider: #{model.provider}")
        end
        [model, provider]
      end

      def method_missing(method, ...)
        instance.respond_to?(method) ? instance.send(method, ...) : super
      end

      def respond_to_missing?(method, include_private = false)
        instance.respond_to?(method, include_private) || super
      end

      private

      def fetch_models
        models = fetch_provider_models + fetch_parsera_models
        models.uniq { |m| [m.provider, m.id] }.sort_by { |m| [m.provider, m.id] }
      end

      def fetch_provider_models
        Provider.configured_providers(RubyLLM.config).flat_map do |provider|
          provider.list_models(connection: provider.connection(RubyLLM.config))
                  .map { |data| ModelInfo.new(data.merge(default_model_attributes)) }
        end
      end

      def fetch_parsera_models
        response = Faraday.new('https://api.parsera.org/v1/llm-specs', request: { timeout: 60 })
                          .get
                          .body
                          .then { |body| JSON.parse(body) }

        response.map { |data| ModelInfo.new(RubyLLM::Utils.symbolize_keys_deep(data)) }
      rescue Faraday::Error => e
        RubyLLM.logger.error "Failed to fetch Parsera models: #{e.message}"
        []
      end

      def default_model_attributes
        {
          modalities: { text: {}, image: {}, audio: {} },
          capabilities: {},
          pricing: { text_tokens: { standard: {}, batch: {} }, embeddings: { standard: {}, batch: {} } },
          embeddings_output: nil
        }
      end
    end

    # Initialize with optional pre-filtered models
    def initialize(models = nil)
      @models = models || load_models
    end

    # Load models from the JSON file
    def load_models
      data = File.exist?(self.class.models_file) ? File.read(self.class.models_file) : '[]'
      JSON.parse(data).map { |model| ModelInfo.new(model.transform_keys(&:to_sym)) }
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

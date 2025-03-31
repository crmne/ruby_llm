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

      def refresh! # rubocop:disable Metrics/AbcSize,Metrics/CyclomaticComplexity,Metrics/PerceivedComplexity
        configured = Provider.configured_providers

        # Log provider status
        skipped = Provider.providers.values - configured
        RubyLLM.logger.info "Refreshing models from #{configured.map(&:slug).join(', ')}" if configured.any?
        RubyLLM.logger.info "Skipping #{skipped.map(&:slug).join(', ')} - providers not configured" if skipped.any?

        # Store current models except from configured providers
        current = instance.load_models
        preserved = current.reject { |m| configured.map(&:slug).include?(m.provider) }

        all = (preserved + configured.flat_map(&:list_models)).sort_by(&:id)
        @instance = new(all)
        @instance
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

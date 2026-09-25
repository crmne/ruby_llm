# frozen_string_literal: true

module RubyLLM
  class Models
    # Finds registry entries by model id, resolving aliases, provider
    # registry ids, and deployments, and preferring first-party providers.
    module Lookup # :nodoc:
      private

      def models_by_id
        models = @models
        index = @model_index
        index = @model_index = [models, models.group_by(&:id)] unless index && index.first.equal?(models)
        index.last
      end

      def find_with_provider(model_id, provider, config = nil)
        deployed_id = Provider.resolve(provider)&.deployed_model_id(model_id, config || RubyLLM.config)
        return find_registered(model_id, provider, config) unless deployed_id

        Model.new(find_deployed_model(model_id, deployed_id, provider, config).to_h.merge(id: model_id))
      end

      def find_deployed_model(deployment, model_id, provider, config)
        find_registered(model_id, provider, config)
      rescue ModelNotFoundError
        raise ConfigurationError, "Deployment #{deployment.inspect} points to unknown model #{model_id.inspect} " \
                                  "for provider: #{provider.inspect}. #{refresh_registry_guidance}"
      end

      def find_registered(model_id, provider, config)
        resolved_id = Aliases.resolve(model_id, provider)
        resolved_id = resolve_provider_registry_id(resolved_id, provider, config)
        index = models_by_id
        Array(index[resolved_id]).find { |m| m.provider == provider.to_s } ||
          Array(index[model_id]).find { |m| m.provider == provider.to_s } ||
          raise_model_not_found(model_id, provider: provider)
      end

      def resolve_provider_registry_id(model_id, provider, config = nil)
        provider_class = Provider.resolve(provider)
        return model_id unless provider_class

        provider_class.resolve_registry_id(model_id, self, config || RubyLLM.config)
      end

      # A name can be one provider's exact id and another's alias:
      # claude-opus-4 is exact on vertexai, an alias on anthropic.
      # Provider preference settles it, not the kind of match.
      def find_without_provider(model_id)
        resolved_id = Aliases.resolve(model_id)
        index = models_by_id
        matches = Array(index[model_id])
        matches += Array(index[resolved_id]) unless resolved_id == model_id

        preferred_match(matches) || raise_model_not_found(model_id)
      end

      def raise_model_not_found(model_id, provider: nil)
        message = "Unknown model: #{model_id.inspect}"
        message = "#{message} for provider: #{provider.inspect}" if provider

        raise ModelNotFoundError, "#{message}. #{refresh_registry_guidance}"
      end

      def refresh_registry_guidance
        'If the model exists at the provider, refresh the registry with `RubyLLM.models.refresh`.'
      end

      def preferred_match(candidates)
        return candidates.first if candidates.size == 1

        candidates.min_by do |model|
          index = PROVIDER_PREFERENCE.index(model.provider)
          [model.unlisted? ? 1 : 0, index || PROVIDER_PREFERENCE.length]
        end
      end
    end
  end
end

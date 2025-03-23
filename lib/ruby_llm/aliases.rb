# frozen_string_literal: true

module RubyLLM
  # Manages model aliases, allowing users to reference models by simpler names
  # that map to specific model versions across different providers.
  #
  # Aliases are defined in aliases.json and follow the format:
  #   {
  #     "simple-name": {
  #       "provider1": "specific-version-for-provider1",
  #       "provider2": "specific-version-for-provider2"
  #     }
  #   }
  class Aliases
    class << self
      # Resolves a model ID to its provider-specific version
      #
      # @param model_id [String] the model identifier or alias
      # @param provider_slug [String, Symbol, nil] optional provider to resolve for
      # @return [String] the resolved model ID or the original if no alias exists
      def resolve(model_id, provider_slug = nil)
        provider_aliases = aliases[model_id]
        return model_id unless provider_aliases

        if provider_slug
          provider_aliases[provider_slug.to_s] || model_id
        else
          provider_aliases.values.first || model_id
        end
      end

      # Returns the loaded aliases mapping
      # @return [Hash] the aliases mapping
      def aliases
        @aliases ||= load_aliases
      end

      # Loads aliases from the JSON file
      # @return [Hash] the loaded aliases
      def load_aliases
        file_path = File.expand_path('aliases.json', __dir__)
        if File.exist?(file_path)
          JSON.parse(File.read(file_path))
        else
          {}
        end
      end

      # Reloads aliases from disk
      # @return [Hash] the reloaded aliases
      def reload!
        @aliases = load_aliases
      end
    end
  end
end

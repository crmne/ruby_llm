# frozen_string_literal: true

module RubyLLM
  module ModelRegistry # :nodoc: all
    class JsonSource # :nodoc:
      def initialize(file = nil)
        @file = file
      end

      def read
        Models.read_from_json(@file || RubyLLM.config.model_registry_file)
      end
    end

    class ActiveRecordSource # :nodoc:
      def read
        model_class = resolve_model_class
        return [] unless model_class.respond_to?(:table_exists?) && model_class.table_exists?

        model_class.all.map(&:to_llm)
      rescue StandardError => e
        RubyLLM.logger.debug { "Failed to load models from database: #{e.message}, falling back to JSON" }
        []
      end

      private

      def resolve_model_class
        model_class = RubyLLM.config.model_registry_class
        return model_class unless model_class.is_a?(String)

        model_class.split('::').inject(Object) { |scope, name| scope.const_get(name) }
      end
    end
  end
end

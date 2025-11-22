# frozen_string_literal: true

require 'ruby_llm/schema'

module RubyLLM
  # Parameter definition for Tool methods.
  class Parameter
    attr_reader :name, :type, :description, :required

    def initialize(name, type: 'string', desc: nil, required: true)
      @name = name
      @type = type
      @description = desc
      @required = required
    end
  end

  # Base class for creating tools that AI models can use
  class Tool
    # Stops conversation continuation after tool execution
    class Halt
      attr_reader :content

      def initialize(content)
        @content = content
      end

      def to_s
        @content.to_s
      end
    end

    class << self
      attr_reader :params_schema_definition

      def description(text = nil)
        return @description unless text

        @description = text
      end

      def param(name, **options)
        parameters[name] = Parameter.new(name, **options)
      end

      def parameters
        @parameters ||= {}
      end

      def params(schema = nil, &block)
        @params_schema_definition = SchemaDefinition.new(schema:, block:)
        self
      end

      def with_params(**params)
        @provider_params = params
        self
      end

      def provider_params
        @provider_params ||= {}
      end
    end

    def name
      klass_name = self.class.name
      normalized = klass_name.to_s.dup.force_encoding('UTF-8').unicode_normalize(:nfkd)
      normalized.encode('ASCII', replace: '')
                .gsub(/[^a-zA-Z0-9_-]/, '-')
                .gsub(/([A-Z]+)([A-Z][a-z])/, '\1_\2')
                .gsub(/([a-z\d])([A-Z])/, '\1_\2')
                .downcase
                .delete_suffix('_tool')
    end

    def description
      self.class.description
    end

    def parameters
      self.class.parameters
    end

    def provider_params
      self.class.provider_params
    end

    def params_schema
      return @params_schema if defined?(@params_schema)

      @params_schema = begin
        definition = self.class.params_schema_definition
        if definition&.present?
          definition.json_schema
        elsif parameters.any?
          SchemaDefinition.from_parameters(parameters)&.json_schema
        end
      end
    end

    def call(args)
      RubyLLM.logger.debug "Tool #{name} called with: #{args.inspect}"
      result = execute(**args.transform_keys(&:to_sym))
      RubyLLM.logger.debug "Tool #{name} returned: #{result.inspect}"
      result
    end

    def execute(...)
      raise NotImplementedError, 'Subclasses must implement #execute'
    end

    protected

    def halt(message)
      Halt.new(message)
    end

    # Wraps schema handling for tool parameters, supporting JSON Schema hashes,
    # RubyLLM::Schema instances/classes, and DSL blocks.
    class SchemaDefinition
      def self.from_parameters(parameters)
        return nil if parameters.nil? || parameters.empty?

        properties = parameters.to_h do |name, param|
          schema = {
            type: map_type(param.type),
            description: param.description
          }.compact

          schema[:items] = default_items_schema if schema[:type] == 'array'

          [name.to_s, schema]
        end

        required = parameters.select { |_, param| param.required }.keys.map(&:to_s)

        json_schema = {
          type: 'object',
          properties: properties,
          required: required,
          additionalProperties: false,
          strict: true
        }

        new(schema: json_schema)
      end

      def self.map_type(type)
        case type.to_s
        when 'integer', 'int' then 'integer'
        when 'number', 'float', 'double' then 'number'
        when 'boolean' then 'boolean'
        when 'array' then 'array'
        when 'object' then 'object'
        else
          'string'
        end
      end

      def self.default_items_schema
        { type: 'string' }
      end

      def initialize(schema: nil, block: nil)
        @schema = schema
        @block = block
      end

      def present?
        @schema || @block
      end

      def json_schema
        @json_schema ||= RubyLLM::Utils.deep_stringify_keys(resolve_schema)
      end

      private

      def resolve_schema
        return resolve_direct_schema(@schema) if @schema
        return build_from_block(&@block) if @block

        nil
      end

      def resolve_direct_schema(schema)
        return extract_schema(schema.to_json_schema) if schema.respond_to?(:to_json_schema)
        return RubyLLM::Utils.deep_dup(schema) if schema.is_a?(Hash)
        if schema.is_a?(Class) && schema.instance_methods.include?(:to_json_schema)
          return extract_schema(schema.new.to_json_schema)
        end

        nil
      end

      def build_from_block(&)
        schema_class = RubyLLM::Schema.create(&)
        extract_schema(schema_class.new.to_json_schema)
      end

      def extract_schema(schema_hash)
        return nil unless schema_hash.is_a?(Hash)

        schema = schema_hash[:schema] || schema_hash['schema'] || schema_hash
        RubyLLM::Utils.deep_dup(schema)
      end
    end
  end
end

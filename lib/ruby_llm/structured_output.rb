# frozen_string_literal: true

module RubyLLM
  module StructuredOutput
    class Schema
      MAX_OBJECT_PROPERTIES = 100
      MAX_NESTING_DEPTH = 5

      class << self
        def string(name = nil, enum: nil, description: nil)
          schema = { type: 'string', enum: enum, description: description }.compact
          name ? add_property(name, schema) : schema
        end

        def number(name = nil, description: nil)
          schema = { type: 'number', description: description }.compact
          name ? add_property(name, schema) : schema
        end

        def boolean(name = nil, description: nil)
          schema = { type: 'boolean', description: description }.compact
          name ? add_property(name, schema) : schema
        end

        def null(name = nil, description: nil)
          schema = { type: 'null', description: description }.compact
          name ? add_property(name, schema) : schema
        end

        def object(name = nil, description: nil, &block)
          sub_schema = Class.new(Schema)
          sub_schema.class_eval(&block)

          schema = {
            type: 'object',
            properties: sub_schema.properties,
            required: sub_schema.required,
            additionalProperties: false,
            description: description
          }.compact

          name ? add_property(name, schema) : schema
        end

        def array(name, type = nil, description: nil, &block)
          items = if block_given?
                    collector = SchemaCollector.new
                    collector.instance_eval(&block)
                    collector.schemas.first
                  elsif type.is_a?(Symbol)
                    case type
                    when :string, :number, :boolean, :null
                      send(type)
                    else
                      ref(type)
                    end
                  else
                    raise ArgumentError, "Invalid array type: #{type}"
                  end

          add_property(name, {
            type: 'array',
            description: description,
            items: items
          }.compact)
        end

        def any_of(name, description: nil, &block)
          collector = SchemaCollector.new
          collector.instance_eval(&block)

          add_property(name, {
            description: description,
            anyOf: collector.schemas
          }.compact)
        end

        def ref(schema_name)
          { '$ref' => "#/$defs/#{schema_name}" }
        end

        def properties
          @properties ||= {}
        end

        def required
          @required ||= []
        end

        def definitions
          @definitions ||= {}
        end

        def define(name, &)
          sub_schema = Class.new(Schema)
          sub_schema.class_eval(&)

          definitions[name] = {
            type: 'object',
            properties: sub_schema.properties,
            required: sub_schema.required
          }
        end

        private

        def add_property(name, definition)
          properties[name.to_sym] = definition
          required << name.to_sym
        end
      end

      # Simple collector that just stores schemas
      class SchemaCollector
        attr_reader :schemas

        def initialize
          @schemas = []
        end

        def method_missing(method_name, ...)
          if Schema.respond_to?(method_name)
            @schemas << Schema.send(method_name, ...)
          else
            super
          end
        end

        def respond_to_missing?(method_name, include_private = false)
          Schema.respond_to?(method_name) || super
        end
      end

      def initialize(name = nil)
        @name = name || self.class.name
        validate_schema
      end

      def json_schema
        {
          name: @name,
          description: 'Schema for the structured response',
          schema: {
            type: 'object',
            properties: self.class.properties,
            required: self.class.required,
            additionalProperties: false,
            strict: true,
            '$defs' => self.class.definitions
          }
        }
      end

      private

      # Validate the schema against defined limits
      def validate_schema
        properties_count = count_properties(self.class.properties)
        raise 'Exceeded maximum number of object properties' if properties_count > MAX_OBJECT_PROPERTIES

        max_depth = calculate_max_depth(self.class.properties)
        raise 'Exceeded maximum nesting depth' if max_depth > MAX_NESTING_DEPTH
      end

      # Count the total number of properties in the schema
      def count_properties(schema)
        return 0 unless schema.is_a?(Hash) && schema[:properties]

        count = schema[:properties].size
        schema[:properties].each_value do |prop|
          count += count_properties(prop)
        end
        count
      end

      # Calculate the maximum nesting depth of the schema
      def calculate_max_depth(schema, current_depth = 1)
        return current_depth unless schema.is_a?(Hash)

        if schema[:type] == 'object' && schema[:properties]
          child_depths = schema[:properties].values.map do |prop|
            calculate_max_depth(prop, current_depth + 1)
          end
          [current_depth, child_depths.max].compact.max
        elsif schema[:items] # For arrays
          calculate_max_depth(schema[:items], current_depth + 1)
        else
          current_depth
        end
      end

      def method_missing(method_name, ...)
        if respond_to_missing?(method_name)
          send(method_name, ...)
        else
          super
        end
      end

      def respond_to_missing?(method_name, include_private = false)
        %i[string number boolean array object any_of null].include?(method_name) || super
      end
    end
  end
end

# frozen_string_literal: true

module RubyLLM
  module Protocols
    class Gemini
      # JSON Schemas as Gemini accepts them. Gemini refuses a schema nested
      # more than 32 levels deep with a bare "Request contains an invalid
      # argument", so a deeper one goes with its deep subschemas moved into
      # $defs and referenced from where they were, which describes the same
      # values in fewer levels.
      module Schemas
        MAX_DEPTH = 32
        HOIST_DEPTH = 16
        DEFINITION_KEYS = %w[$defs definitions].freeze
        SCHEMA_MAPS = %w[properties patternProperties dependentSchemas $defs definitions].freeze
        SCHEMA_LISTS = %w[anyOf oneOf allOf prefixItems].freeze
        SCHEMA_VALUES = %w[items additionalProperties additionalItems unevaluatedProperties unevaluatedItems
                           not if then else contains propertyNames].freeze

        module_function

        def render_schema(schema)
          return schema unless schema.is_a?(Hash) && nesting(schema) > MAX_DEPTH

          schema = Support::Utils.deep_stringify_keys(schema)
          movable?(schema) ? Hoisting.new(schema).schema : schema
        end

        def movable?(schema)
          references_only_definitions?(schema) && !identified?(schema.except('$id'))
        end

        def nesting(value)
          case value
          when Hash then 1 + (value.values.map { |child| nesting(child) }.max || 0)
          when Array then 1 + (value.map { |child| nesting(child) }.max || 0)
          else 0
          end
        end

        # A reference into the schema's own structure, such as
        # "#/properties/address", would point at a subschema that moved.
        def references_only_definitions?(value)
          case value
          when Hash
            value.all? do |key, child|
              key == '$ref' ? definition_reference?(child) : references_only_definitions?(child)
            end
          when Array then value.all? { |child| references_only_definitions?(child) }
          else true
          end
        end

        # Only a whole definition, since a pointer into one could pass
        # through a subschema that moved.
        def definition_reference?(reference)
          !reference.is_a?(String) || !reference.start_with?('#') ||
            DEFINITION_KEYS.any? { |key| reference.match?(%r{\A#/#{Regexp.escape(key)}/[^/]+\z}) }
        end

        # A nested $id starts a resource of its own, whose references
        # resolve against it rather than the root.
        def identified?(value)
          case value
          when Hash then value.key?('$id') || value.values.any? { |child| identified?(child) }
          when Array then value.any? { |child| identified?(child) }
          else false
          end
        end

        # Rewrites one schema, moving each subschema at HOIST_DEPTH or
        # deeper into the root's definitions.
        class Hoisting
          attr_reader :schema

          def initialize(schema)
            @key = DEFINITION_KEYS.find { |key| schema[key].is_a?(Hash) } || '$defs'
            @definitions = schema.fetch(@key, {}).dup
            @count = 0
            @definitions.keys.each { |name| @definitions[name] = rewrite(@definitions[name], 3) }
            @schema = rewrite(schema.except(@key), 1).merge(@key => @definitions)
          end

          private

          def rewrite(schema, depth)
            return schema unless schema.is_a?(Hash)
            return hoist(schema) if depth >= HOIST_DEPTH

            schema.to_h { |key, value| [key, rewrite_value(key, value, depth)] }
          end

          def rewrite_value(key, value, depth)
            case [position(key), value]
            in [:map, Hash] then value.transform_values { |child| rewrite(child, depth + 2) }
            in [:list, Array] then value.map { |child| rewrite(child, depth + 2) }
            in [:value, _] then rewrite(value, depth + 1)
            else value
            end
          end

          def position(key)
            if SCHEMA_MAPS.include?(key) then :map
            elsif SCHEMA_LISTS.include?(key) then :list
            elsif SCHEMA_VALUES.include?(key) then :value
            end
          end

          def hoist(schema)
            name = next_name
            @definitions[name] = rewrite(schema, 3)
            { '$ref' => "#/#{@key}/#{name}" }
          end

          def next_name
            loop do
              @count += 1
              name = "nested#{@count}"
              return name unless @definitions.key?(name)
            end
          end
        end
      end
    end
  end
end

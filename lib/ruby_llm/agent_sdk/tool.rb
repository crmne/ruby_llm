# frozen_string_literal: true

module RubyLLM
  module AgentSDK
    class Tool
      attr_reader :name, :description, :input_schema, :handler

      def initialize(name:, description:, input_schema: {}, &handler)
        @name = name.to_s
        @description = description
        @input_schema = normalize_schema(input_schema)
        @handler = handler
      end

      def call(input)
        @handler.call(input)
      end

      def to_mcp_schema
        {
          name: @name,
          description: @description,
          inputSchema: @input_schema
        }
      end

      # Adapter from existing RubyLLM::Tool class
      def self.from_ruby_llm_tool(tool_class)
        instance = tool_class.new
        new(
          name: instance.name,
          description: tool_class.description,
          input_schema: convert_parameters(tool_class.parameters)
        ) { |args| instance.call(**args.transform_keys(&:to_sym)) }
      end

      private

      def normalize_schema(schema)
        return schema if schema[:type]

        {
          type: 'object',
          properties: schema,
          required: schema.keys.map(&:to_s)
        }
      end

      class << self
        def convert_parameters(params)
          return {} unless params

          properties = {}
          required = []

          params.each do |name, param|
            properties[name.to_s] = {
              type: ruby_type_to_json(param.type),
              description: param.description
            }
            required << name.to_s if param.required
          end

          { type: 'object', properties: properties, required: required }
        end

        def ruby_type_to_json(type)
          case type.to_s.downcase
          when 'string' then 'string'
          when 'integer', 'int' then 'integer'
          when 'float', 'number' then 'number'
          when 'boolean', 'bool' then 'boolean'
          when 'array' then 'array'
          when 'hash', 'object' then 'object'
          else 'string'
          end
        end
      end
    end
  end
end

# frozen_string_literal: true

module RubyLLM
  module AgentSDK
    # Custom tool definition for extending agent capabilities
    #
    # Tools allow you to give Claude access to custom functionality.
    # Define tools with a name, description, input schema, and handler.
    #
    # @example Define a calculator tool
    #   Tool.new(
    #     name: 'calculator',
    #     description: 'Performs basic arithmetic',
    #     input_schema: {
    #       type: :object,
    #       properties: {
    #         a: { type: :number, description: 'First number' },
    #         b: { type: :number, description: 'Second number' },
    #         op: { type: :string, description: 'Operation: add, sub, mul, div' }
    #       },
    #       required: %i[a b op]
    #     }
    #   ) do |input|
    #     case input[:op]
    #     when 'add' then input[:a] + input[:b]
    #     when 'sub' then input[:a] - input[:b]
    #     when 'mul' then input[:a] * input[:b]
    #     when 'div' then input[:a] / input[:b]
    #     end.to_s
    #   end
    class Tool
      attr_reader :name, :description, :input_schema, :handler

      # @param name [String, Symbol] Tool name (snake_case recommended)
      # @param description [String] What this tool does
      # @param input_schema [Hash] JSON Schema for input validation
      # @yield [Hash] Block to execute when tool is called
      def initialize(name:, description:, input_schema: {}, &handler)
        @name = name.to_s
        @description = description
        @input_schema = normalize_schema(input_schema)
        @handler = handler || ->(_) { raise NotImplementedError, "No handler for tool #{@name}" }
      end

      # Execute the tool with given input
      #
      # @param input [Hash] Tool input parameters
      # @return [String, Hash] Tool result
      def call(input)
        validated_input = validate_input(input)
        handler.call(validated_input)
      end
      alias execute call

      # Convert to hash for serialization
      #
      # @return [Hash]
      def to_h
        {
          name: name,
          description: description,
          input_schema: input_schema
        }
      end

      # Convert to JSON Schema format for Claude
      #
      # @return [Hash]
      def to_json_schema
        {
          type: 'function',
          function: {
            name: name,
            description: description,
            parameters: input_schema
          }
        }
      end

      # Create from a hash definition
      #
      # @param hash [Hash] Tool definition
      # @return [Tool]
      def self.from_h(hash, &handler)
        new(
          name: hash[:name] || hash['name'],
          description: hash[:description] || hash['description'],
          input_schema: hash[:input_schema] || hash['input_schema'] || {},
          &handler
        )
      end

      private

      def normalize_schema(schema)
        return {} if schema.nil? || schema.empty?

        # Deep symbolize keys
        deep_symbolize(schema)
      end

      def deep_symbolize(obj)
        case obj
        when Hash
          obj.transform_keys(&:to_sym).transform_values { |v| deep_symbolize(v) }
        when Array
          obj.map { |v| deep_symbolize(v) }
        else
          obj
        end
      end

      def validate_input(input)
        # Basic validation - check required fields
        required = input_schema[:required] || []
        required.each do |field|
          field_sym = field.to_sym
          field_str = field.to_s
          unless input.key?(field_sym) || input.key?(field_str)
            raise ArgumentError, "Missing required field: #{field}"
          end
        end

        # Symbolize input keys for consistency
        input.transform_keys(&:to_sym)
      end
    end

    # Registry for managing multiple tools
    #
    # @example Register tools
    #   registry = ToolRegistry.new
    #   registry.register(calculator_tool)
    #   registry.register(file_reader_tool)
    #
    #   # Execute by name
    #   result = registry.call('calculator', expression: '2+2')
    class ToolRegistry
      include Enumerable

      def initialize
        @tools = {}
      end

      # Register a tool
      #
      # @param tool [Tool] Tool to register
      # @return [Tool]
      def register(tool)
        @tools[tool.name] = tool
        tool
      end
      alias << register

      # Get a tool by name
      #
      # @param name [String, Symbol] Tool name
      # @return [Tool, nil]
      def [](name)
        @tools[name.to_s]
      end
      alias get []

      # Check if a tool exists
      #
      # @param name [String, Symbol] Tool name
      # @return [Boolean]
      def include?(name)
        @tools.key?(name.to_s)
      end

      # Execute a tool by name
      #
      # @param name [String, Symbol] Tool name
      # @param input [Hash] Tool input
      # @return [String, Hash] Tool result
      def call(name, **input)
        tool = self[name]
        raise ArgumentError, "Unknown tool: #{name}" unless tool

        tool.call(input)
      end

      # Iterate over all tools
      #
      # @yield [Tool]
      def each(&block)
        @tools.values.each(&block)
      end

      # Get all tool names
      #
      # @return [Array<String>]
      def names
        @tools.keys
      end

      # Get count of registered tools
      #
      # @return [Integer]
      def size
        @tools.size
      end
      alias count size

      # Convert to array of tool definitions
      #
      # @return [Array<Hash>]
      def to_a
        @tools.values.map(&:to_h)
      end

      # Convert to JSON Schema array for Claude
      #
      # @return [Array<Hash>]
      def to_json_schema
        @tools.values.map(&:to_json_schema)
      end
    end
  end
end

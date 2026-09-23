# frozen_string_literal: true

module RubyLLM
  class MCP
    # A tool offered by an MCP server. It works anywhere a Tool does: a
    # chat renders its name, description, and schema for the model, and
    # calling it calls the server.
    #
    #   tool = linear.tools.first
    #   tool.read_only?  # => true
    #   chat.with_tools(tool)
    #
    # The behavior predicates read the server's annotations. They are hints
    # from the server, so trust them only as far as you trust the server.
    class Tool < RubyLLM::Tool
      include Support::Inspectable

      # The name the model calls this tool by.
      attr_reader :name

      # The description the model sees.
      attr_reader :description

      # The JSON Schema for the arguments the model provides.
      attr_reader :parameters_schema

      # The tool's name on the server.
      attr_reader :server_name

      attr_reader :fixed_arguments, :wrap # :nodoc:

      def initialize(mcp, definition, as: nil, description: nil, fixed_arguments: {}, wrap: nil) # :nodoc:
        super()
        @mcp = mcp
        @server_name = definition['name']
        @name = (as || server_name).to_s
        @description = description || definition['description']
        @fixed_arguments = fixed_arguments.transform_keys(&:to_sym)
        @wrap = wrap
        @annotations = definition['annotations'] || {}
        @parameters_schema = model_schema(definition['inputSchema'] || {})
      end

      # Returns whether the server says the tool only reads.
      def read_only?
        @annotations['readOnlyHint'] == true
      end

      # Returns whether the tool may destroy or overwrite data. Tools that
      # are not read-only count as destructive unless the server says
      # otherwise.
      def destructive?
        !read_only? && @annotations['destructiveHint'] != false
      end

      # Returns whether calling the tool again with the same arguments has
      # no further effect.
      def idempotent?
        @annotations['idempotentHint'] == true
      end

      # Returns whether the tool reaches beyond the server, such as the web.
      def open_world?
        @annotations['openWorldHint'] != false
      end

      # Returns whether the tool pauses for approval, as declared with
      # MCP.requires_approval.
      def requires_approval?
        @mcp.requires_approval?(self)
      end

      # Calls the tool on the server and returns what the model sees: the
      # result's content, what the +wrap:+ method made of it, or
      # <tt>{ error: }</tt> when the tool failed.
      def call(**arguments)
        @mcp.run(self, arguments.except(:tool_call))
      end

      private

      def model_schema(schema)
        schema = SchemaDefinition.new(schema:).json_schema
        return schema if fixed_arguments.empty? || !schema.key?('properties')

        hidden = fixed_arguments.keys.map(&:to_s)
        schema.merge('properties' => schema['properties'].except(*hidden),
                     'required' => Array(schema['required']) - hidden)
      end

      def inspect_attributes
        { name:, from: (server_name unless server_name == name), read_only: read_only? || nil }
      end
    end
  end
end

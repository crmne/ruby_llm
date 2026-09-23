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

      # The JSON Schema for the tool's arguments.
      attr_reader :parameters_schema

      def initialize(mcp, definition) # :nodoc:
        super()
        @mcp = mcp
        @name = definition['name']
        @description = definition['description']
        @parameters_schema = SchemaDefinition.new(schema: definition['inputSchema'] || {}).json_schema
        @annotations = definition['annotations'] || {}
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

      # Calls the tool on the server and returns what the model sees: the
      # result's content, or <tt>{ error: }</tt> when the tool failed.
      def call(**arguments)
        result = @mcp.call(name, **arguments.except(:tool_call))
        result.error? ? { error: result.text } : result.content
      end

      private

      def inspect_attributes
        { name:, read_only: read_only? || nil }
      end
    end
  end
end

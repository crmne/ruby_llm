# frozen_string_literal: true

module RubyLLM
  class MCP
    # Reads what the MCP Apps extension keeps in a tool's _meta: the UI that
    # renders the tool's results, and who may call the tool. Servers on
    # older SDKs name the UI with the flat ui/resourceUri key the spec
    # deprecated.
    module Apps # :nodoc:
      EXTENSION = 'io.modelcontextprotocol/ui'
      MIME_TYPE = 'text/html;profile=mcp-app'
      VISIBILITY = %w[model app].freeze

      module_function

      def uri(meta)
        meta.dig('ui', 'resourceUri') || meta['ui/resourceUri']
      end

      def visibility(meta)
        Array(meta.dig('ui', 'visibility') || VISIBILITY).map(&:to_sym)
      end
    end
  end
end

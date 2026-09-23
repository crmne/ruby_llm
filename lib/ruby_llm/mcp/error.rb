# frozen_string_literal: true

module RubyLLM
  class MCP
    # Raised when an MCP server answers with a JSON-RPC error, an unexpected
    # HTTP status, or not at all.
    #
    #   begin
    #     github.search_issues(query: "flaky")
    #   rescue RubyLLM::MCP::Error => e
    #     e.code  # => -32602
    #   end
    class Error < RubyLLM::Error
      # The JSON-RPC error code, or +nil+ when the failure had none.
      attr_reader :code

      # Additional information the server attached to the error, or +nil+.
      attr_reader :data

      def initialize(message = nil, code: nil, data: nil, response: nil) # :nodoc:
        @code = code
        @data = data
        super(message, response:)
      end
    end
  end
end

# frozen_string_literal: true

module RubyLLM
  class MCP
    # Raised when an MCP server refuses a request because the token lacks a
    # scope it needs. The message carries the server's reason, and #scopes
    # the scopes it asked for. RubyLLM never widens a grant by itself: to
    # grant them, send the user through MCP#authorization_url again.
    #
    #   begin
    #     chat.ask "List the open issues in crmne/ruby_llm"
    #   rescue RubyLLM::MCP::InsufficientScopeError => e
    #     e.message  # => "api.githubcopilot.com refused the request: Additional scopes required: repo"
    #     e.scopes   # => ["repo"]
    #   end
    class InsufficientScopeError < RubyLLM::ForbiddenError
      # The scopes the server's challenge asked for, as Strings. Empty when
      # it named none.
      attr_reader :scopes

      def initialize(message = nil, scopes: [], **) # :nodoc:
        @scopes = scopes
        super(message, **)
      end
    end
  end
end

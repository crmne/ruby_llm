# frozen_string_literal: true

module RubyLLM
  class MCP
    # Raised by a transport when the session of a server that predates
    # 2026-07-28 has ended, so the client starts a new one: the server
    # answered 404, or its stdio process exited. +session+ is the session
    # that ended, as the transport's +session+ reader returned it.
    class SessionExpired < Error # :nodoc:
      attr_reader :session

      def initialize(message = nil, session: nil, **)
        @session = session
        super(message, **)
      end
    end
  end
end

# frozen_string_literal: true

module RubyLLM
  class MCP
    # Raised by a transport when the session of a server that predates
    # 2026-07-28 has ended, so the client starts a new one: the server
    # answered 404, or its stdio process exited.
    class SessionExpired < Error; end # :nodoc:
  end
end

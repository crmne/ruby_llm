# frozen_string_literal: true

module RubyLLM
  class MCP
    # Raised when a server needs input from the user and no
    # MCP.before_input_request callback answered. Its message includes what
    # the server asked for, and #requests has the MCP::InputRequest objects.
    class InputRequiredError < Error
      # The unanswered MCP::InputRequest objects.
      attr_reader :requests

      def initialize(server, requests) # :nodoc:
        @requests = requests
        asks = requests.map { |request| [request.message, request.url].compact.join(' ') }
        super("#{server} needs input from the user: #{asks.join('; ')}")
      end
    end
  end
end

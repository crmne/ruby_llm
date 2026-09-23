# frozen_string_literal: true

module RubyLLM
  class MCP
    # Raised when a server needs input from the user and no
    # MCP.before_input_request callback answered. Its message includes what
    # the server asked for, and #requests has the MCP::InputRequest objects.
    # In a chat, the tool call pauses instead, and Chat#pending_inputs
    # returns the requests.
    class InputRequiredError < Error
      def initialize(server, input) # :nodoc:
        @input = input
        asks = requests.map { |request| [request.message, request.url].compact.join(' ') }
        super("#{server} needs input from the user: #{asks.join('; ')}")
      end

      # The unanswered MCP::InputRequest objects.
      def requests
        @input['requests'].reject(&:answered?)
      end

      # Returns everything needed to answer the requests later and resume
      # the call, as a Hash that serializes to JSON.
      def to_h # :nodoc:
        { 'requests' => @input['requests'].map(&:to_h), 'request_state' => @input['request_state'] }.compact
      end
    end
  end
end

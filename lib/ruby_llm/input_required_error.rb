# frozen_string_literal: true

module RubyLLM
  # Raised when a tool needs input from the user and nothing answered it:
  # an MCP server's question (MCP::InputRequiredError), or a tool's own
  # Tool#ask. Its message includes what was asked, and #requests has the
  # InputRequest objects. In a chat, the tool call pauses instead, and
  # Chat#pending_inputs returns the requests.
  class InputRequiredError < Error
    def initialize(source, input) # :nodoc:
      @input = input
      asks = requests.map { |request| [request.message, request.url].compact.join(' ') }
      super("#{source} needs input from the user: #{asks.join('; ')}")
    end

    # The unanswered InputRequest objects.
    def requests
      @input['requests'].reject(&:answered?)
    end

    # Returns everything needed to answer the requests later and resume
    # the call, as a Hash that serializes to JSON.
    def to_h # :nodoc:
      @input.merge('requests' => @input['requests'].map(&:to_h)).compact
    end
  end
end

# frozen_string_literal: true

module RubyLLM
  # Raised when a tool asks a person something and nothing can pause the
  # call for the answer: Tool#ask outside a chat, or an MCP server's
  # question that no MCP.before_input_request callback answered when you
  # call the tool yourself (MCP::InputRequiredError). Its message includes
  # what was asked, and #requests has the Question objects. In a chat, the
  # tool call pauses instead, and Chat#pending_questions returns them.
  class InputRequiredError < Error
    def initialize(source, input) # :nodoc:
      @input = input
      asks = requests.map { |question| [question.message, question.url].compact.join(' ') }
      super("#{source} needs input from the user: #{asks.join('; ')}")
    end

    # The unanswered Question objects.
    def requests
      @input['requests'].reject(&:answered?)
    end

    # Returns everything needed to answer the questions later and resume
    # the call, as a Hash that serializes to JSON.
    def to_h # :nodoc:
      @input.merge('requests' => @input['requests'].map(&:to_h)).compact
    end
  end
end

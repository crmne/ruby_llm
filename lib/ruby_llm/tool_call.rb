# frozen_string_literal: true

module RubyLLM
  # A ToolCall is a request from an AI model to invoke a Tool with specific
  # arguments. Instances appear in Message#tool_calls and are yielded to
  # tool callbacks such as Chat#before_tool_call.
  #
  #   chat.before_tool_call do |tool_call|
  #     puts "Calling tool: #{tool_call.name}"
  #     puts "Arguments: #{tool_call.arguments}"
  #   end
  #
  class ToolCall
    # The unique identifier for this call. The tool result message
    # answering this call carries the same id.
    attr_reader :id

    # The name of the tool the model wants to invoke.
    attr_reader :name

    # The arguments the model supplied for the invocation, as a Hash.
    attr_reader :arguments

    # The Gemini thought signature attached to this call, or +nil+.
    # RubyLLM replays it to the provider on later requests.
    attr_accessor :thought_signature

    def initialize(id:, name:, arguments: {}, thought_signature: nil) # :nodoc:
      @id = id
      @name = name
      @arguments = arguments
      @thought_signature = thought_signature
    end

    # Returns a Hash with the keys +:id+, +:name+, +:arguments+, and
    # +:thought_signature+. Keys with +nil+ values are omitted.
    def to_h
      {
        id: @id,
        name: @name,
        arguments: @arguments,
        thought_signature: @thought_signature
      }.compact
    end
  end
end

# frozen_string_literal: true

module RubyLLM
  # A ToolCall is a request to run a tool with specific arguments. Instances
  # appear in Message#tool_calls. Local calls are yielded to tool callbacks
  # such as Chat#before_tool_call. Remote calls awaiting approval return
  # +true+ from #remote? and appear in Chat#pending_approvals.
  #
  #   chat.before_tool_call do |tool_call|
  #     puts "Calling tool: #{tool_call.name}"
  #     puts "Arguments: #{tool_call.arguments}"
  #   end
  #
  class ToolCall
    include Support::Inspectable

    # The unique identifier for this call. The tool result message
    # answering this call carries the same id.
    attr_reader :id

    # The name of the tool the model wants to invoke.
    attr_reader :name

    # The arguments the model supplied for the invocation, as a Hash.
    attr_reader :arguments

    # Returns +true+ if the provider executes this call after approval.
    # Local tools executed by the application return +false+.
    def remote? = @remote

    # The Gemini thought signature attached to this call, or +nil+.
    # RubyLLM replays it to the provider on later requests.
    attr_accessor :thought_signature

    def initialize(id:, name:, arguments: {}, thought_signature: nil, remote: false) # :nodoc:
      @id = id
      @name = name
      @arguments = arguments
      @thought_signature = thought_signature
      @remote = remote
    end

    def inspect_attributes # :nodoc:
      { id: id, name: name, arguments: arguments, remote: remote? || nil }.compact
    end

    # Returns the call as a Hash, omitting +nil+ values.
    def to_h
      {
        id: @id,
        name: @name,
        arguments: @arguments,
        remote: remote? || nil,
        thought_signature: @thought_signature
      }.compact
    end
  end
end

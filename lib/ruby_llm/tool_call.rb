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

    def self.index(calls) # :nodoc:
      calls.each_with_object({}) do |call, indexed|
        raise Error, "Duplicate tool call ID in one response: #{call.id.inspect}" if indexed.key?(call.id)

        indexed[call.id] = call
      end
    end

    # The RubyLLM identifier for this invocation. The tool result message
    # answering this call carries the same id, including after a reload.
    # This is independent of the ID in the provider's response.
    attr_reader :id

    # The name of the tool the model wants to invoke.
    attr_reader :name

    # The arguments the model supplied for the invocation, as a Hash. Keys
    # are ordered the way PostgreSQL +jsonb+ and MySQL +json+ store them,
    # shorter keys first, so a call reloaded from the database renders the
    # same request bytes and keeps the provider's prompt cache.
    attr_reader :arguments

    # Returns +true+ if the provider executes this call after approval.
    # Local tools executed by the application return +false+.
    def remote? = @remote

    # The Gemini thought signature attached to this call, or +nil+.
    # RubyLLM replays it to the provider on later requests.
    attr_accessor :thought_signature

    def initialize(id:, name:, arguments: {}, thought_signature: nil, remote: false, provider_id: nil) # :nodoc:
      @id = id
      @provider_id = provider_id
      @name = name
      @arguments = canonical_arguments(arguments)
      @thought_signature = thought_signature
      @remote = remote
    end

    def provider_id = @provider_id || id # :nodoc:

    def with_id(id) # :nodoc:
      dup.tap do |call|
        call.instance_variable_set(:@provider_id, provider_id)
        call.instance_variable_set(:@id, id)
      end
    end

    def inspect_attributes # :nodoc:
      { id: id, name: name, arguments: arguments, remote: remote? || nil }.compact
    end

    # Returns the call as a Hash, omitting +nil+ values.
    def to_h
      {
        id: @id,
        provider_id: @provider_id,
        name: @name,
        arguments: @arguments,
        remote: remote? || nil,
        thought_signature: @thought_signature
      }.compact
    end

    private

    def canonical_arguments(value)
      case value
      when Hash
        value.sort_by { |key, _| [key.to_s.bytesize, key.to_s] }
             .to_h { |key, nested| [key, canonical_arguments(nested)] }
      when Array then value.map { |item| canonical_arguments(item) }
      else value
      end
    end
  end
end

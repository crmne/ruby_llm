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

    def self.index(calls, by: :id) # :nodoc:
      calls.each_with_object({}) do |call, indexed|
        id = call.public_send(by) || call.provider_call_id
        raise Error, "Duplicate tool call ID in one response: #{id.inspect}" if indexed.key?(id)

        indexed[id] = call
      end
    end

    # The RubyLLM identifier for this invocation. The tool result message
    # answering this call carries the same id, including after a reload.
    # This is independent of the ID in the provider's response.
    attr_reader :id

    # The name of the tool the model wants to invoke.
    attr_reader :name

    # The namespace of the tool the model wants to invoke, or +nil+ for a
    # tool without one. See Tool.namespace.
    attr_reader :namespace

    def qualified_name # :nodoc:
      namespace ? "#{namespace}_#{name}" : name
    end

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

    def self.parse_arguments(text, response: nil, finish_reason: nil) # :nodoc:
      return { arguments: text } if text.is_a?(Hash)

      text = JSON.generate(text) unless text.nil? || text.is_a?(String)
      return { arguments: {} } if text.nil? || text.empty?

      { arguments: Hash(JSON.parse(text)) }
    rescue JSON::ParserError, TypeError => e
      raise ToolCallTruncatedError.new(response:), cause: e if finish_reason == :max_tokens

      { malformed_arguments: text }
    end

    def initialize(name:, id: nil, provider_call_id: nil, arguments: {}, thought_signature: nil,
                   remote: false, namespace: nil, malformed_arguments: nil) # :nodoc:
      @id = id
      @provider_call_id = provider_call_id
      @name = name
      @namespace = namespace&.to_s
      @malformed_arguments = malformed_arguments
      @arguments = malformed_arguments ? {} : canonical_arguments(arguments)
      @thought_signature = thought_signature
      @remote = remote
    end

    # The provider's argument text when it was not a JSON object, or +nil+.
    # A call with such text has empty #arguments and never runs.
    attr_reader :malformed_arguments # :nodoc:

    def malformed_arguments? = !@malformed_arguments.nil? # :nodoc:

    def malformed_arguments_problem # :nodoc:
      JSON.parse(@malformed_arguments)
      'not a JSON object'
    rescue JSON::ParserError => e
      "not valid JSON (#{e.message})"
    end

    def provider_call_id = @provider_call_id || id # :nodoc:

    def with_id(id) # :nodoc:
      dup.tap do |call|
        call.instance_variable_set(:@provider_call_id, provider_call_id)
        call.instance_variable_set(:@id, id)
      end
    end

    def inspect_attributes # :nodoc:
      { id: id, name: name, namespace: namespace, arguments: arguments, remote: remote? || nil,
        malformed_arguments: malformed_arguments }.compact
    end

    # Returns the call as a Hash, omitting +nil+ values.
    def to_h
      {
        id: @id,
        provider_call_id: @provider_call_id,
        name: @name,
        namespace: @namespace,
        arguments: @arguments,
        malformed_arguments: @malformed_arguments,
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

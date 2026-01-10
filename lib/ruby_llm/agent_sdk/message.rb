# frozen_string_literal: true

module RubyLLM
  module AgentSDK
    # Dynamic message class that handles all SDK message types
    #
    # Instead of a hierarchy of message classes, this single class
    # uses duck typing to handle all message types from the Claude CLI.
    # Type-specific behavior is provided via predicate methods.
    #
    # @example Basic usage
    #   message = Message.new(type: :assistant, content: "Hello!")
    #   message.assistant? # => true
    #   message.content # => "Hello!"
    #
    # @example Accessing arbitrary data
    #   message = Message.new(type: :result, session_id: "abc123", cost_usd: 0.05)
    #   message.session_id # => "abc123"
    #   message.cost_usd # => 0.05
    class Message
      attr_reader :type, :data

      # All known message types
      MESSAGE_TYPES = %i[
        system
        user
        assistant
        result
        partial
        init
        tool_use
        tool_result
        error
      ].freeze

      # @param json [Hash] Parsed JSON data from the stream
      def initialize(json)
        @data = (json || {}).freeze
        @type = extract_type(json)
      end

      # Define predicate methods for each message type
      MESSAGE_TYPES.each do |t|
        define_method(:"#{t}?") { type == t }
      end

      # Dynamic attribute access for any field in the data
      #
      # @param name [Symbol] Attribute name
      # @return [Object, nil] Attribute value
      def method_missing(name, *args)
        key_sym = name.to_sym
        key_str = name.to_s

        return @data[key_sym] if @data.key?(key_sym)
        return @data[key_str] if @data.key?(key_str)

        super
      end

      def respond_to_missing?(name, include_private = false)
        @data.key?(name.to_sym) || @data.key?(name.to_s) || super
      end

      # Get message content (handles multiple field names)
      #
      # @return [String, nil]
      def content
        @data[:content] || @data['content'] ||
          @data[:text] || @data['text'] ||
          @data[:message] || @data['message']
      end

      # Get message role
      #
      # @return [Symbol, nil]
      def role
        role_val = @data[:role] || @data['role']
        role_val&.to_sym
      end

      # Get tool calls from message
      #
      # @return [Array<Hash>]
      def tool_calls
        @data[:tool_use] || @data['tool_use'] ||
          @data[:tool_calls] || @data['tool_calls'] ||
          []
      end

      # Get session ID (handles camelCase and snake_case)
      #
      # @return [String, nil]
      def session_id
        @data[:session_id] || @data['session_id'] ||
          @data[:sessionId] || @data['sessionId']
      end

      # Get cost in USD (handles camelCase and snake_case)
      #
      # @return [Float, nil]
      def cost_usd
        @data[:cost_usd] || @data['cost_usd'] ||
          @data[:costUsd] || @data['costUsd']
      end

      # Get input tokens used
      #
      # @return [Integer, nil]
      def input_tokens
        @data[:input_tokens] || @data['input_tokens'] ||
          @data[:inputTokens] || @data['inputTokens']
      end

      # Get output tokens used
      #
      # @return [Integer, nil]
      def output_tokens
        @data[:output_tokens] || @data['output_tokens'] ||
          @data[:outputTokens] || @data['outputTokens']
      end

      # Get stop reason
      #
      # @return [String, nil]
      def stop_reason
        @data[:stop_reason] || @data['stop_reason'] ||
          @data[:stopReason] || @data['stopReason']
      end

      # Convert to hash
      #
      # @return [Hash]
      def to_h
        @data.dup
      end

      # Convert to JSON string
      #
      # @return [String]
      def to_json(*args)
        @data.to_json(*args)
      end

      private

      def extract_type(json)
        return :unknown unless json

        # Check explicit type field
        type_val = json[:type] || json['type']
        return type_val.to_sym if type_val && !type_val.empty?

        # Infer from content
        infer_type(json)
      end

      def infer_type(json)
        role_val = json[:role] || json['role']

        case role_val
        when 'assistant' then :assistant
        when 'user' then :user
        when 'system' then :system
        else
          infer_from_content(json)
        end
      end

      def infer_from_content(json)
        return :tool_use if json[:tool_use] || json['tool_use'] || json[:tool_calls] || json['tool_calls']
        return :tool_result if json[:tool_result] || json['tool_result']
        return :result if json[:session_id] || json['session_id'] || json[:sessionId] || json['sessionId']
        return :error if json[:error] || json['error']

        :unknown
      end
    end
  end
end

# frozen_string_literal: true

module RubyLLM
  module AgentSDK
    class Message
      attr_reader :type, :data

      MESSAGE_TYPES = %i[
        system user assistant result partial init
        tool_use tool_result error
      ].freeze

      def initialize(json)
        @data = json.freeze
        @type = json[:type]&.to_sym || infer_type(json)
      end

      # Type predicates
      MESSAGE_TYPES.each do |t|
        define_method(:"#{t}?") { type == t }
      end

      # Dynamic attribute access
      def method_missing(name, *args)
        return @data[name] if @data.key?(name)
        return @data[name.to_s] if @data.key?(name.to_s)

        super
      end

      def respond_to_missing?(name, include_private = false)
        @data.key?(name) || @data.key?(name.to_s) || super
      end

      # Common accessors
      def content
        @data[:content] || @data[:text] || @data[:message]
      end

      def role
        @data[:role]&.to_sym
      end

      def tool_calls
        @data[:tool_use] || @data[:tool_calls] || []
      end

      def session_id
        @data[:session_id] || @data[:sessionId]
      end

      def cost_usd
        @data[:cost_usd] || @data[:costUsd]
      end

      def to_h
        @data
      end

      private

      def infer_type(json)
        return :assistant if json[:role] == 'assistant'
        return :user if json[:role] == 'user'
        return :system if json[:role] == 'system'
        return :tool_use if json[:tool_use] || json[:tool_calls]
        return :tool_result if json[:tool_result]

        :unknown
      end
    end
  end
end

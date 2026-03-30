# frozen_string_literal: true

module RubyLLM
  module ActiveRecord
    # Methods mixed into tool call models.
    module ToolCallMethods
      extend ActiveSupport::Concern

      def tool_error_message
        payload = parse_payload(arguments)
        return unless payload.is_a?(Hash)

        payload['error'] || payload[:error]
      end

      private

      def parse_payload(value)
        return value if value.is_a?(Hash) || value.is_a?(Array)
        return if value.blank?

        JSON.parse(value)
      rescue JSON::ParserError
        nil
      end
    end
  end
end

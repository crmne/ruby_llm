# frozen_string_literal: true

module RubyLLM
  module ActiveRecord
    # Shared helpers for parsing serialized payloads on ActiveRecord-backed models.
    module PayloadHelpers
      private

      def payload_error_message(value)
        payload = parse_payload(value)
        return unless payload.is_a?(Hash)

        payload['error'] || payload[:error]
      end

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

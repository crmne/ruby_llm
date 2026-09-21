# frozen_string_literal: true

module RubyLLM
  module Protocols
    # The System One protocol for typed questions and probabilistic answers.
    class SystemOne < Protocol
      include SystemOne::Models
      include SystemOne::Judgments
      include SystemOne::Responses

      def parse_error_response(response)
        body = response.body.is_a?(String) ? JSON.parse(response.body) : response.body
        return unless body.is_a?(Hash)

        detail = body['detail']
        case detail
        when String
          detail
        when Hash
          detail['message']
        when Array
          detail.map do |error|
            [Array(error['loc']).join('.'), error['msg']].compact.reject(&:empty?).join(': ')
          end.join('; ')
        end
      rescue JSON::ParserError
        nil
      end
    end
  end
end

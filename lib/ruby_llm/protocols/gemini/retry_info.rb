# frozen_string_literal: true

module RubyLLM
  module Protocols
    class Gemini
      # Google says how long to wait in the error body, as a
      # google.rpc.RetryInfo detail, rather than in a header.
      module RetryInfo # :nodoc: all
        DURATION = /\A\d{1,12}(\.\d{1,9})?s\z/

        def retry_delay(response)
          retry_info_details(parse_error_body(response)).filter_map { |detail| retry_info_seconds(detail) }.max
        end

        private

        def retry_info_details(body)
          errors = [body].flatten.grep(Hash).map { |part| part['error'] }.grep(Hash)
          errors.flat_map { |error| error['details'] }.grep(Hash)
        end

        def retry_info_seconds(detail)
          delay = detail['retryDelay']
          delay.to_f if delay.is_a?(String) && delay.match?(DURATION)
        end
      end
    end
  end
end

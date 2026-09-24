# frozen_string_literal: true

require 'faraday'
require 'faraday/response/json'

module RubyLLM
  module Transport
    # Faraday before 2.14.4 passes parser options positionally, which JSON 3 rejects.
    class JsonResponse < Faraday::Response::Json # :nodoc:
      private

      def parse(body)
        return if body.strip.empty?

        decoder, method_name = @decoder_options || [::JSON, :parse]
        decoder.public_send(method_name, body, **(@parser_options || {}))
      end
    end
  end
end

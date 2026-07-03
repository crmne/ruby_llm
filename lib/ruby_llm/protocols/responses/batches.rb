# frozen_string_literal: true

module RubyLLM
  module Protocols
    class Responses
      # OpenAI file-backed Batch API for Responses requests.
      module Batches
        include Protocols::OpenAI::Batches

        private

        def batch_endpoint
          '/v1/responses'
        end

        def validate_batch_requests!(requests)
          return if requests.all? { |request| responses_payload?(request.fetch(:params)) }

          raise Error, "#{@provider.slug} batch requests require responses payloads"
        end

        def responses_payload?(params)
          params.key?(:input) || params.key?('input')
        end

        def parse_batch_completion_response(body)
          parse_completion_body(body, raw: body)
        end
      end
    end
  end
end

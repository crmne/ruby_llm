# frozen_string_literal: true

module RubyLLM
  module Protocols
    class ChatCompletions
      # OpenAI-compatible file-backed Batch API for Chat Completions.
      module Batches
        include Protocols::OpenAI::Batches

        private

        def batch_endpoint
          '/v1/chat/completions'
        end

        def validate_batch_requests!(requests)
          return if requests.all? { |request| chat_completion_payload?(request.fetch(:params)) }

          raise Error, "#{@provider.slug} batch requests require chat completion payloads"
        end

        def chat_completion_payload?(params)
          params.key?(:messages) || params.key?('messages')
        end

        def parse_batch_completion_response(body)
          parse_completion_body(body, raw: body)
        end
      end
    end
  end
end

# frozen_string_literal: true

module RubyLLM
  module Protocols
    module Perplexity
      # Perplexity's Batch API, the OpenAI batch shape for Agent API requests.
      module Batches
        include Protocols::Responses::Batches

        # The Idempotency-Key lets the connection retry the create after a 429,
        # which arrives whenever the upload just used the 1 request per second
        # that the batch and file endpoints allow at the lowest usage tier.
        def create_batch(requests)
          single_batch_model!(requests, @provider.slug)
          validate_batch_requests!(requests)

          payload = { input_file_id: upload_batch_file(requests), endpoint: batch_endpoint, completion_window: '24h' }
          response = @connection.post(batch_create_url, payload) do |request|
            request.headers['Idempotency-Key'] = SecureRandom.uuid
          end

          parse_batch_response(response.body)
        end

        private

        def batch_create_url
          'v1/batches'
        end

        def batch_url(id)
          "v1/batches/#{id}"
        end
      end
    end
  end
end

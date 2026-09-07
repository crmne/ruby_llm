# frozen_string_literal: true

module RubyLLM
  module Providers
    class Mistral
      class ChatCompletions
        # Mistral batch jobs for chat completions and embeddings.
        module Batches
          include RubyLLM::Batch::Helpers

          TERMINAL_STATUSES = %w[SUCCESS FAILED TIMEOUT_EXCEEDED CANCELLED].freeze
          Response = Struct.new(:body)
          private_constant :TERMINAL_STATUSES, :Response

          def create_batch(requests)
            model = single_batch_model!(requests, 'mistral')
            response = @connection.post('batch/jobs', {
                                          endpoint: mistral_batch_endpoint(requests),
                                          model: model,
                                          requests: requests.map { |request| mistral_batch_request(request) }
                                        }, idempotent: false)

            parse_batch_response(response.body)
          end

          def find_batch(id)
            attempts = 0
            begin
              parse_batch_response @connection.get(batch_url(id)).body
            rescue Error => e
              attempts += 1
              raise unless e.response&.status == 404 && attempts < 3

              sleep(0.5 * attempts)
              retry
            end
          end

          def cancel_batch(id)
            parse_batch_response @connection.post("#{batch_url(id)}/cancel", {}).body
          end

          def batch_results(id)
            response = @connection.get(batch_url(id)) { |request| request.params[:inline] = true }
            Array(response.body['outputs']).filter_map { |line| parse_batch_result(line) }
          end

          private

          def batch_url(id)
            "batch/jobs/#{id}"
          end

          def mistral_batch_request(request)
            body = batch_payload(request, except: :model)
            custom_id = request[:custom_id]
            custom_id = "#{custom_id}:array" if (body[:input] || body['input']).is_a?(Array)

            {
              custom_id: custom_id,
              body: body
            }
          end

          def mistral_batch_endpoint(requests)
            endpoints = requests.map do |request|
              payload = request.fetch(:payload)
              payload.key?(:input) || payload.key?('input') ? '/v1/embeddings' : '/v1/chat/completions'
            end.uniq
            return endpoints.first if endpoints.one?

            raise Error, 'Mistral batches cannot mix chat and embedding requests'
          end

          def parse_batch_response(data)
            {
              id: data['id'],
              raw_status: data['status'],
              completed: TERMINAL_STATUSES.include?(data['status']),
              request_count: data['total_requests'],
              request_counts: {
                'total' => data['total_requests'],
                'completed' => data['completed_requests'],
                'succeeded' => data['succeeded_requests'],
                'failed' => data['failed_requests']
              }.compact
            }
          end

          def parse_batch_status(raw_status, completed:)
            return :pending unless completed
            return :succeeded if raw_status == 'SUCCESS'
            return :cancelled if raw_status == 'CANCELLED'

            :failed
          end

          def parse_batch_result(line)
            custom_id, shape = line['custom_id'].split(':', 2)
            index = batch_result_index(custom_id)
            response = line['response']

            if response && response['body']
              body = response['body']
              [index, parse_mistral_batch_body(body, shape:)]
            else
              [index, nil, batch_failure(line['custom_id'], batch_error_message(line))]
            end
          end

          def parse_mistral_batch_body(body, shape:)
            return parse_completion_body(body, raw: body) unless body['data'].is_a?(Array)

            parse_embedding_response(Response.new(body), model: body['model'], text: shape == 'array' ? [] : nil)
          end
        end
      end
    end
  end
end

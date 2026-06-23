# frozen_string_literal: true

module RubyLLM
  module Providers
    class Mistral
      class ChatCompletions
        # Mistral batch jobs for chat completions.
        module Batches
          include RubyLLM::Batch::Helpers

          TERMINAL_STATUSES = %w[SUCCESS FAILED TIMEOUT_EXCEEDED CANCELLED].freeze
          private_constant :TERMINAL_STATUSES

          def create_batch(requests)
            model = single_batch_model!(requests, 'mistral')
            response = @connection.post('batch/jobs', {
                                          endpoint: '/v1/chat/completions',
                                          model: model,
                                          requests: requests.map { |request| mistral_batch_request(request) }
                                        })

            parse_batch_response(response.body)
          end

          def find_batch(id)
            parse_batch_response @connection.get(batch_url(id)).body
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
            {
              custom_id: request[:custom_id],
              body: batch_params(request, except: :model)
            }
          end

          def parse_batch_response(data)
            {
              id: data['id'],
              status: data['status'],
              completed: TERMINAL_STATUSES.include?(data['status']),
              request_counts: {
                'total' => data['total_requests'],
                'completed' => data['completed_requests'],
                'succeeded' => data['succeeded_requests'],
                'failed' => data['failed_requests']
              }.compact
            }
          end

          def parse_batch_result(line)
            index = batch_result_index(line['custom_id'])
            response = line['response']

            if response && response['body']
              body = response['body']
              [index, parse_completion_body(body, raw: body)]
            else
              batch_failure(line['custom_id'], batch_error_message(line))
              [index, nil]
            end
          end
        end
      end
    end
  end
end

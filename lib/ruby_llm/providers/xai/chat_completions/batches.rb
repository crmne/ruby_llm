# frozen_string_literal: true

module RubyLLM
  module Providers
    class XAI
      class ChatCompletions
        # xAI native batch containers. Requests submit in Responses or Chat
        # Completions shape; results always come back as chat completions.
        module Batches
          include RubyLLM::Batch::Helpers

          def create_batch(requests)
            batch = @connection.post('batches', { name: "ruby_llm_#{SecureRandom.hex(8)}" },
                                     idempotent: false).body
            id = batch['batch_id'] || batch['id']
            @connection.post("batches/#{id}/requests", {
                               batch_requests: requests.map { |request| xai_batch_request(request) }
                             }, idempotent: false)

            find_batch(id)
          end

          def find_batch(id)
            parse_batch_response @connection.get("batches/#{id}").body
          end

          def cancel_batch(id)
            parse_batch_response @connection.post("batches/#{id}:cancel", {}).body
          end

          def batch_results(id)
            results = []
            token = nil

            loop do
              response = @connection.get("batches/#{id}/results") do |request|
                request.params[:limit] = 100
                request.params[:pagination_token] = token if token
              end.body

              page_results = Array(response['results'] || response['batch_results'])
              results.concat(page_results.map { |result| parse_batch_result(result) })
              token = response['pagination_token'] || response['next_page_token']
              break unless token
            end

            results
          end

          private

          def xai_batch_request(request)
            payload = batch_payload(request)
            {
              batch_request_id: request[:custom_id],
              batch_request: { batch_request_type(payload) => payload }
            }
          end

          def batch_request_type(payload)
            payload.key?(:input) || payload.key?('input') ? :responses : :chat_get_completion
          end

          def parse_batch_response(data)
            state = data['state'] || {}
            completed = completed_batch_state?(state)
            {
              id: data['batch_id'] || data['id'],
              raw_status: data['state'] ? xai_batch_status(state, completed:) : data['status'],
              completed:,
              request_count: state['num_requests'],
              request_counts: state
            }
          end

          def parse_batch_status(raw_status, completed:)
            return :pending unless completed

            raw_status == 'failed' ? :failed : :succeeded
          end

          def xai_batch_status(state, completed:)
            return 'failed' unless state['error'].to_s.empty?

            completed ? 'completed' : 'processing'
          end

          def completed_batch_state?(state)
            state['num_requests'].to_i.positive? && state['num_pending'].to_i.zero?
          end

          def parse_batch_result(result)
            request_id = result['batch_request_id'] || result['custom_id']
            index = batch_result_index(request_id)
            body = result.dig('batch_result', 'response', 'chat_get_completion') ||
                   result.dig('response', 'chat_get_completion')

            if body
              [index, parse_completion_body(body, raw: body)]
            else
              [index, nil, batch_failure(request_id, batch_error_message(result))]
            end
          end
        end
      end
    end
  end
end

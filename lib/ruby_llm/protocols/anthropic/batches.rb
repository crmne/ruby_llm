# frozen_string_literal: true

module RubyLLM
  module Protocols
    class Anthropic
      # The Message Batches API: Messages requests processed together,
      # asynchronously, at half price.
      module Batches
        include RubyLLM::Batch::Helpers

        def create_batch(requests)
          requests = requests.map { |request| request.slice(:custom_id, :params) }
          response = @connection.post batches_url, { requests: requests }
          parse_batch_response response.body
        end

        def find_batch(id)
          parse_batch_response @connection.get(batch_url(id)).body
        end

        def cancel_batch(id)
          parse_batch_response @connection.post("#{batch_url(id)}/cancel", {}).body
        end

        # Results come back as JSONL in no particular order; each line carries
        # the custom_id (our submission index) to match results to requests.
        def batch_results(id)
          response = @connection.get "#{batch_url(id)}/results"
          response.body.each_line.map { |line| parse_batch_result JSON.parse(line) }
        end

        private

        def batches_url
          'v1/messages/batches'
        end

        def batch_url(id)
          "v1/messages/batches/#{id}"
        end

        def parse_batch_response(data)
          {
            id: data['id'],
            status: data['processing_status'],
            completed: data['processing_status'] == 'ended',
            request_counts: data['request_counts']
          }
        end

        def parse_batch_result(line)
          index = batch_result_index(line['custom_id'])
          result = line['result']

          if result['type'] == 'succeeded'
            body = result['message']
            [index, parse_completion_body(body, raw: body)]
          else
            batch_failure(line['custom_id'], result.dig('error', 'error', 'message'), status: result['type'])
            [index, nil]
          end
        end
      end
    end
  end
end

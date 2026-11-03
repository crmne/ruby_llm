# frozen_string_literal: true

module RubyLLM
  module Protocols
    class Anthropic
      # The Message Batches API: Messages requests processed together,
      # asynchronously, at half price.
      module Batches
        include RubyLLM::Batch::Helpers

        def create_batch(requests)
          headers = batch_betas(requests)
          requests = requests.map { |request| { custom_id: request[:custom_id], params: request[:payload] } }
          response = @connection.post(batches_url, { requests: requests }, idempotent: false) do |request|
            request.headers.merge!(headers)
          end
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

        # One request carries the whole batch, so it takes every beta any
        # of its entries needs.
        def batch_betas(requests)
          requests.reduce({}) do |headers, request|
            payload = request[:payload]
            headers = beta_headers(with_request_betas(headers, request), payload)
            headers = apply_mcp_beta(headers) if block_value(payload, :mcp_servers)
            compaction = block_value(payload, :context_management)
            compaction ? apply_compaction_headers(headers, compaction) : headers
          end
        end

        def with_request_betas(headers, request)
          betas = canonical_beta_headers(request[:headers].to_h)[Chat::BETA_HEADER]
          betas ? add_beta(headers, betas) : headers
        end

        def batches_url
          'v1/messages/batches'
        end

        def batch_url(id)
          "v1/messages/batches/#{id}"
        end

        def parse_batch_response(data)
          request_counts = data['request_counts']
          completed = data['processing_status'] == 'ended'

          {
            id: data['id'],
            raw_status: completed ? ended_batch_status(request_counts) : data['processing_status'],
            completed:,
            request_counts:,
            request_count: request_counts&.values&.sum
          }
        end

        # Anthropic ends every batch as "ended"; only the request counts say
        # whether it was cancelled or ran out of time. A batch with any
        # success ended, and its cancelled or expired slots fail on their own.
        def ended_batch_status(request_counts)
          return 'ended' if request_counts&.fetch('succeeded', 0).to_i.positive?

          %w[canceled expired].find { |outcome| request_counts&.fetch(outcome, 0).to_i.positive? } || 'ended'
        end

        def parse_batch_status(raw_status, completed:)
          return :pending unless completed

          case raw_status
          when 'ended' then :succeeded
          when 'canceled' then :cancelled
          when 'expired' then :failed
          else :pending
          end
        end

        def parse_batch_result(line)
          index = batch_result_index(line['custom_id'])
          result = line['result']

          if result['type'] == 'succeeded'
            body = result['message']
            [index, parse_completion_body(body, raw: body)]
          else
            status = batch_failure(line['custom_id'], result.dig('error', 'error', 'message'), status: result['type'])
            [index, nil, status]
          end
        end
      end
    end
  end
end

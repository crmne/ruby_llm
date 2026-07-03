# frozen_string_literal: true

require 'stringio'

module RubyLLM
  module Protocols
    module OpenAI
      # The OpenAI file-backed Batch API: upload JSONL, create /batches,
      # then read output/error files back in custom_id order.
      module Batches
        include RubyLLM::Batch::Helpers

        TERMINAL_STATUSES = %w[completed failed expired cancelled].freeze
        private_constant :TERMINAL_STATUSES

        def create_batch(requests)
          single_batch_model!(requests, @provider.slug)
          validate_batch_requests!(requests)

          response = @connection.post(batch_create_url, {
                                        input_file_id: upload_batch_file(requests),
                                        endpoint: batch_endpoint,
                                        completion_window: '24h'
                                      })

          parse_batch_response(response.body)
        end

        def find_batch(id)
          parse_batch_response @connection.get(batch_url(id)).body
        end

        def cancel_batch(id)
          parse_batch_response @connection.post("#{batch_url(id)}/cancel", {}).body
        end

        # Results are JSONL and may arrive out of order. Each line carries the
        # custom_id we assigned from the submission index.
        def batch_results(id)
          batch = @connection.get(batch_url(id)).body
          %w[output_file_id error_file_id].flat_map do |key|
            file_id = batch[key]
            next [] unless file_id && !file_id.to_s.empty?

            download_batch_file(file_id).to_s.each_line.filter_map { |line| parse_batch_result(JSON.parse(line)) }
          end
        end

        private

        def upload_batch_file(requests)
          @provider.upload_file(
            StringIO.new(batch_jsonl(requests)),
            purpose: 'batch',
            filename: 'ruby_llm_batch.jsonl'
          ).id
        end

        def download_batch_file(file_id)
          @provider.download_file(file_id)
        end

        def batch_jsonl(requests)
          requests.map { |request| JSON.generate(batch_request_line(request)) }.join("\n")
        end

        def batch_request_line(request)
          {
            custom_id: request[:custom_id],
            method: 'POST',
            url: batch_endpoint,
            body: batch_params(request)
          }
        end

        def validate_batch_requests!(_requests); end

        def batch_endpoint
          raise NotImplementedError
        end

        def batch_create_url
          'batches'
        end

        def batch_url(id)
          "batches/#{id}"
        end

        def parse_batch_response(data)
          {
            id: data['id'],
            status: data['status'],
            completed: TERMINAL_STATUSES.include?(data['status']),
            request_counts: data['request_counts'],
            endpoint: data['endpoint']
          }.compact
        end

        def parse_batch_result(line)
          index = batch_result_index(line['custom_id'])
          response = line['response']

          if response && response['status_code'].to_i.between?(200, 299)
            [index, parse_batch_completion_response(response['body'])]
          else
            batch_failure(line['custom_id'], batch_error_message(line))
            [index, nil]
          end
        end
      end
    end
  end
end

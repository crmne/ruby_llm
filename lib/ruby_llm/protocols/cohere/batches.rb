# frozen_string_literal: true

module RubyLLM
  module Protocols
    class Cohere
      module Batches # :nodoc: all
        include RubyLLM::Batch::Helpers
        include Cohere::BatchRequests

        TERMINAL_STATUSES = %w[BATCH_STATUS_COMPLETED BATCH_STATUS_FAILED BATCH_STATUS_CANCELED].freeze
        Response = Struct.new(:body)
        private_constant :TERMINAL_STATUSES, :Response

        def create_batch(requests)
          model = single_batch_model!(requests, 'Cohere')
          type = batch_dataset_type(requests)
          rows = requests.map { |request| render_batch_request(request, type:) }
          file = datasets.upload(StringIO.new(rows.map { |row| "#{JSON.generate(row)}\n" }.join),
                                 filename: 'ruby-llm-batch.jsonl', purpose: type)
          datasets.wait_for_validation(file.id)
          response = @connection.post('v2/batches', {
                                        name: 'ruby-llm-batch', input_dataset_id: file.id, model: model
                                      }, idempotent: false)
          parse_batch_response(response.body.fetch('batch'))
        end

        def find_batch(id)
          parse_batch_response(batch_data(id))
        end

        def cancel_batch(id)
          @connection.post("v2/batches/#{id}/cancel", {})
          find_batch(id)
        end

        def batch_results(id)
          data = batch_data(id)
          return [] if data['output_dataset_id'].to_s.empty?

          file = datasets.wait_for_validation(data.fetch('output_dataset_id'))
          model = RubyLLM.models.find(data.fetch('model'), provider: @provider.slug, config: @config)
          parser = self.class.new(@provider, model)
          results = datasets.records(file).map { |row| parse_batch_result(row, parser:, model: model.id) }
          unless results.map(&:first).uniq.size == results.size
            raise Error,
                  'Cohere returned duplicate batch request IDs'
          end

          results
        end

        private

        def datasets
          @datasets ||= Cohere::Datasets.new(@provider)
        end

        def batch_data(id)
          @connection.get("v2/batches/#{id}").body.fetch('batch')
        end

        def parse_batch_response(data)
          {
            id: data.fetch('id'), raw_status: data.fetch('status'),
            completed: TERMINAL_STATUSES.include?(data['status']), request_count: data['num_records'],
            request_counts: {
              'total' => data['num_records'], 'succeeded' => data['num_successful_records'],
              'failed' => data['num_failed_records']
            }.compact
          }
        end

        def parse_batch_status(raw_status, completed:)
          return :pending unless completed
          return :succeeded if raw_status == 'BATCH_STATUS_COMPLETED'
          return :cancelled if raw_status == 'BATCH_STATUS_CANCELED'

          :failed
        end

        def parse_batch_result(row, parser:, model:)
          custom_id, shape = row.fetch('custom_id').split(':', 2)
          index = batch_result_index(custom_id)
          return [index, nil, batch_failure(custom_id, row['error'])] if !row['error'].to_s.empty? || !row['body']

          body = row.fetch('body')
          result = if body['embeddings']
                     parser.send(:parse_embedding_response, Response.new(body), model:,
                                                                                text: shape == 'array' ? [] : nil)
                   else
                     parser.send(:parse_completion_body, body, raw: body)
                   end
          [index, result]
        end
      end
    end
  end
end

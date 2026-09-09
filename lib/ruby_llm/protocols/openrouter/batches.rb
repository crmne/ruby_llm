# frozen_string_literal: true

module RubyLLM
  module Protocols
    module OpenRouter
      module Batches # :nodoc: all
        include RubyLLM::Batch::Helpers

        TERMINAL_STATUSES = %w[completed failed expired cancelled].freeze
        MEDIA_TYPES = %w[image image_url input_image input_audio audio video video_url input_video file input_file
                         document].freeze
        Response = Struct.new(:body)
        private_constant :TERMINAL_STATUSES, :MEDIA_TYPES, :Response

        def create_batch(requests)
          model = single_batch_model!(requests, 'OpenRouter')
          endpoints = requests.map { |request| batch_request_endpoint(request) }.uniq
          raise ArgumentError, 'OpenRouter batches require one API protocol per submission' unless endpoints.one?

          endpoint = endpoints.first
          rows = requests.map { |request| render_batch_request(request, endpoint:) }
          response = @connection.post(@provider.batch_api_base, { endpoint:, model:, requests: rows },
                                      idempotent: false)
          parse_batch_response(response.body)
        end

        def find_batch(id)
          parse_batch_response(batch_data(id))
        end

        def cancel_batch(_id)
          raise Error, 'OpenRouter does not expose batch cancellation'
        end

        def batch_results(id)
          data = batch_data(id)
          results = Array(data['results']).map { |row| parse_batch_result(row, data:) }
          unless results.map(&:first).uniq.size == results.size
            raise Error, 'OpenRouter returned duplicate batch request IDs'
          end

          results
        end

        private

        def batch_data(id)
          @connection.get("#{@provider.batch_api_base}/#{id}").body
        end

        def batch_request_endpoint(request)
          return '/v1/embeddings' if request.key?(:text)

          payload = Support::Utils.deep_symbolize_keys(request.fetch(:payload))
          return '/v1/chat/completions' if payload.key?(:messages)
          return '/v1/responses' if payload.key?(:input)

          raise ArgumentError, 'OpenRouter batches require chat or embedding requests'
        end

        def render_batch_request(request, endpoint:)
          body = Support::Utils.deep_symbolize_keys(batch_payload(request))
          validate_batch_body(body, endpoint:)
          id = request.fetch(:custom_id)
          id = "#{id}:array" if endpoint == '/v1/embeddings' && request.fetch(:text).is_a?(Array)
          { custom_id: id, body: }
        end

        def validate_batch_body(body, endpoint:)
          if endpoint == '/v1/embeddings'
            unsupported = body.keys & %i[input_type provider]
            if unsupported.any? || !text_embedding_input?(body[:input])
              raise ArgumentError,
                    'OpenRouter embedding batches accept text only, without task_type or provider preferences'
            end
          elsif batch_media?(body) || body.keys.intersect?(%i[modalities audio image_config])
            raise ArgumentError, 'OpenRouter batches accept text input and output only'
          end
        end

        def text_embedding_input?(input)
          case input
          when String then true
          when Array then input.flatten.all? { |part| part.is_a?(String) || part.is_a?(Integer) }
          else false
          end
        end

        def batch_media?(value)
          case value
          when Hash then MEDIA_TYPES.include?(value[:type]) || value.values.any? { |part| batch_media?(part) }
          when Array then value.any? { |part| batch_media?(part) }
          else false
          end
        end

        def parse_batch_response(data)
          {
            id: data.fetch('id'), raw_status: data.fetch('status'),
            completed: TERMINAL_STATUSES.include?(data['status']),
            reported_cost: parse_batch_reported_cost(data['usage']),
            request_counts: data['request_counts'], request_count: data.dig('request_counts', 'total')
          }
        end

        def parse_batch_reported_cost(usage)
          return if usage.nil? || usage['cost'].nil?

          Cost.from_h({ total: usage.fetch('cost') })
        end

        def parse_batch_status(raw_status, completed:)
          return :pending unless completed
          return :succeeded if raw_status == 'completed'
          return :cancelled if raw_status == 'cancelled'

          :failed
        end

        def parse_batch_result(row, data:)
          custom_id, shape = row.fetch('custom_id').split(':', 2)
          index = batch_result_index(custom_id)
          response = row['response']
          unless response && response['status_code'].to_i.between?(200, 299) && !row['error']
            return [index, nil, batch_failure(custom_id, batch_error_message(row))]
          end

          [index, parse_batch_body(response.fetch('body'), endpoint: data.fetch('endpoint'),
                                                           model: data.fetch('model'), shape:)]
        end

        def parse_batch_body(body, endpoint:, model:, shape:)
          return parse_batch_embedding(body, model:, shape:) if endpoint == '/v1/embeddings'

          parser = endpoint == '/v1/responses' ? OpenRouter::Responses.new(@provider) : self
          parser.send(:parse_completion_body, body, raw: body)
        end

        def parse_batch_embedding(body, model:, shape:)
          ordered = body.merge('data' => body.fetch('data').sort_by { |row| row.fetch('index') })
          parse_embedding_response(Response.new(ordered), model: body['model'] || model,
                                                          text: shape == 'array' ? [] : nil)
        end
      end
    end
  end
end

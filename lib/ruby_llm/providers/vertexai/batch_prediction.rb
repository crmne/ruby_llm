# frozen_string_literal: true

require 'stringio'

module RubyLLM
  module Providers
    class VertexAI
      # Shared Vertex AI batchPredictionJobs plumbing. The input row and output
      # result shapes belong to each Vertex protocol.
      module BatchPrediction
        include RubyLLM::Batch::Helpers

        TERMINAL = %w[
          JOB_STATE_SUCCEEDED
          JOB_STATE_FAILED
          JOB_STATE_CANCELLED
          JOB_STATE_EXPIRED
          JOB_STATE_PARTIALLY_SUCCEEDED
        ].freeze
        private_constant :TERMINAL

        def create_batch(requests)
          model = single_batch_model!(requests, 'vertexai')
          validate_batch_requests!(requests)
          input_uri, output_uri = vertex_batch_storage_uris
          @provider.upload_file(StringIO.new(vertex_batch_jsonl(requests)),
                                uri: input_uri, filename: 'input.jsonl', content_type: 'application/jsonl')

          response = @connection.post("#{@provider.location_path}/batchPredictionJobs",
                                      vertex_batch_job(model, input_uri, output_uri))

          parse_batch_response(response.body)
        end

        def find_batch(id)
          parse_batch_response @connection.get(vertex_batch_name(id)).body
        end

        def cancel_batch(id)
          @connection.post("#{vertex_batch_name(id)}:cancel", {})
          find_batch(id)
        end

        def batch_results(id)
          job = @connection.get(vertex_batch_name(id)).body
          output_uri = vertex_output_uri(job)
          raise Error, 'vertexai batch has no GCS output URI yet' unless output_uri

          index = -1
          @provider.list_file_uris(output_uri).grep(/\.jsonl\z/).flat_map do |uri|
            @provider.download_file(uri).to_s.each_line.filter_map do |line|
              next if line.strip.empty?

              index += 1
              parse_vertex_batch_result(JSON.parse(line), index)
            end
          end
        end

        private

        def vertex_batch_job(model, input_uri, output_uri)
          {
            displayName: "ruby_llm_#{SecureRandom.hex(8)}",
            model: vertex_batch_model_path(model),
            inputConfig: {
              instancesFormat: 'jsonl',
              gcsSource: { uris: [input_uri] }
            },
            outputConfig: {
              predictionsFormat: 'jsonl',
              gcsDestination: { outputUriPrefix: output_uri }
            }
          }
        end

        def vertex_batch_jsonl(requests)
          requests.map { |request| JSON.generate(vertex_batch_request(request)) }.join("\n")
        end

        def vertex_batch_request(_request)
          raise NotImplementedError
        end

        def validate_batch_requests!(_requests); end

        def vertex_batch_model_path(model)
          @provider.model_path(model)
        end

        def vertex_batch_storage_uris
          base = @config.vertexai_batch_gcs_uri.to_s.sub(%r{/+\z}, '')
          if base.empty?
            raise ConfigurationError, 'Set vertexai_batch_gcs_uri to a gs:// bucket prefix for Vertex AI batches'
          end

          prefix = "#{base}/ruby_llm_batches/#{SecureRandom.hex(8)}"
          ["#{prefix}/input.jsonl", "#{prefix}/output"]
        end

        def vertex_batch_name(id)
          id.to_s.start_with?('projects/') ? id : "#{@provider.location_path}/batchPredictionJobs/#{id}"
        end

        def parse_batch_response(data)
          state = data['state']
          {
            id: data['name'],
            status: state,
            completed: TERMINAL.include?(state),
            request_counts: data['completionStats'],
            model: data['model']
          }
        end

        def vertex_batch_result_index(line, fallback_index)
          key = line['custom_id'] || line.dig('request', 'labels', 'ruby_llm_batch_id')
          key ? batch_result_index(key) : fallback_index
        end

        def parse_vertex_batch_result(_line, _fallback_index)
          raise NotImplementedError
        end

        def vertex_output_uri(job)
          job.dig('outputInfo', 'gcsOutputDirectory') ||
            job.dig('outputConfig', 'gcsDestination', 'outputUriPrefix')
        end
      end
    end
  end
end

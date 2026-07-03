# frozen_string_literal: true

require 'digest'
require 'stringio'
require 'uri'

module RubyLLM
  module Protocols
    class Converse
      # Bedrock Model Invocation Jobs for Converse payloads.
      module Batches
        include RubyLLM::Batch::Helpers

        TERMINAL = %w[Completed PartiallyCompleted Failed Stopped Expired].freeze
        private_constant :TERMINAL

        def create_batch(requests)
          model = single_batch_model!(requests, 'bedrock')
          validate_bedrock_batch_requests!(requests)
          role_arn = bedrock_batch_role_arn
          input_uri, output_uri = bedrock_batch_storage_uris
          @provider.upload_file(StringIO.new(bedrock_batch_jsonl(requests)),
                                uri: input_uri, filename: 'input.jsonl', content_type: 'application/jsonl')

          response = @provider.signed_post(@provider.control_api_base, '/model-invocation-job', {
                                             jobName: bedrock_job_name(input_uri),
                                             roleArn: role_arn,
                                             modelId: model,
                                             modelInvocationType: 'Converse',
                                             inputDataConfig: {
                                               s3InputDataConfig: { s3Uri: input_uri }
                                             },
                                             outputDataConfig: {
                                               s3OutputDataConfig: { s3Uri: output_uri }
                                             }
                                           })

          find_batch(response.body['jobArn'])
        end

        def find_batch(id)
          parse_batch_response @provider.signed_get(@provider.control_api_base, bedrock_job_url(id)).body
        end

        def cancel_batch(id)
          @provider.signed_post(@provider.control_api_base, "#{bedrock_job_url(id)}/stop", {})
          find_batch(id)
        end

        def batch_results(id)
          job = @provider.signed_get(@provider.control_api_base, bedrock_job_url(id)).body
          output_uri = job.dig('outputDataConfig', 's3OutputDataConfig', 's3Uri')
          raise Error, 'bedrock batch has no S3 output URI yet' unless output_uri

          @provider.list_file_uris(output_uri)
                   .grep(/\.jsonl\.out\z/)
                   .reject { |uri| uri.end_with?('/manifest.json.out') }
                   .flat_map { |uri| parse_bedrock_output(@provider.download_file(uri)) }
        end

        private

        def bedrock_batch_jsonl(requests)
          requests.map do |request|
            JSON.generate(recordId: request[:custom_id], modelInput: batch_params(request))
          end.join("\n")
        end

        def bedrock_batch_storage_uris
          base = @config.bedrock_batch_s3_uri.to_s.sub(%r{/+\z}, '')
          if base.empty?
            raise ConfigurationError, 'Set bedrock_batch_s3_uri to an s3:// bucket prefix for Bedrock batches'
          end

          prefix = "#{base}/ruby_llm_batches/#{SecureRandom.hex(8)}"
          ["#{prefix}/input.jsonl", "#{prefix}/output"]
        end

        def bedrock_batch_role_arn
          @config.bedrock_batch_role_arn ||
            raise(ConfigurationError, 'Set bedrock_batch_role_arn for Bedrock batches')
        end

        def bedrock_job_name(input_uri)
          "ruby-llm-#{Digest::SHA256.hexdigest(input_uri)[0, 16]}"
        end

        def bedrock_job_url(id)
          "/model-invocation-job/#{URI.encode_www_form_component(id)}"
        end

        def validate_bedrock_batch_requests!(requests)
          unsupported = requests.any? do |request|
            params = request.fetch(:params)
            params.key?(:toolConfig) || params.key?('toolConfig') ||
              params.key?(:outputConfig) || params.key?('outputConfig')
          end
          return unless unsupported

          raise Error, 'bedrock batch requests do not support tools or structured output'
        end

        def parse_batch_response(data)
          status = data['status']
          {
            id: data['jobArn'] || data['jobIdentifier'],
            status: status,
            completed: TERMINAL.include?(status),
            request_counts: bedrock_request_counts(data)
          }
        end

        def bedrock_request_counts(data)
          {
            'submitted' => data['submitTime'],
            'completed' => data['endTime']
          }.compact
        end

        def parse_bedrock_output(body)
          body.to_s.each_line.filter_map { |line| parse_bedrock_record(JSON.parse(line)) }
        end

        def parse_bedrock_record(line)
          record_id = line['recordId'] || line['record_id']
          index = batch_result_index(record_id)

          if line['modelOutput']
            body = line['modelOutput']
            [index, parse_completion_body(body, raw: body)]
          else
            batch_failure(record_id, line.dig('error', 'message') || line['errorMessage'])
            [index, nil]
          end
        end
      end
    end
  end
end

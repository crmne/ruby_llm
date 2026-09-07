# frozen_string_literal: true

require 'digest'
require 'stringio'
require 'uri'

module RubyLLM
  module Protocols
    module Bedrock
      # Shared Bedrock Model Invocation Job and S3 result lifecycle.
      module Batches
        include RubyLLM::Batch::Helpers

        TERMINAL = %w[Completed PartiallyCompleted Failed Stopped Expired].freeze
        private_constant :TERMINAL

        def create_batch(requests)
          model = single_batch_model!(requests, 'bedrock')
          validate_bedrock_batch_requests!(requests)
          role_arn = bedrock_batch_role_arn
          input_uri, output_uri = bedrock_batch_storage_uris
          @provider.upload_file(
            StringIO.new(bedrock_batch_jsonl(requests)),
            filename: 'input.jsonl',
            uri: input_uri,
            content_type: 'application/jsonl'
          )

          response = @provider.signed_post(@provider.control_api_base, '/model-invocation-job', {
                                             clientRequestToken: Digest::SHA256.hexdigest(input_uri),
                                             jobName: bedrock_job_name(input_uri, requests:),
                                             roleArn: role_arn,
                                             modelId: model,
                                             modelInvocationType: bedrock_invocation_type,
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
          data = @provider.signed_get(@provider.control_api_base, bedrock_job_url(id)).body
          protocol = @provider.embedding_batch_protocol(data['modelId']) if data['modelInvocationType'] == 'InvokeModel'
          parser = protocol ? protocol.new(@provider) : self
          parser.send(:parse_batch_response, data).tap do |result|
            result[:batch_protocol] = protocol if protocol
          end
        end

        def cancel_batch(id)
          @provider.signed_post(@provider.control_api_base, "#{bedrock_job_url(id)}/stop", {})
          find_batch(id)
        end

        def batch_results(id)
          job = @provider.signed_get(@provider.control_api_base, bedrock_job_url(id)).body
          output_uri = job.dig('outputDataConfig', 's3OutputDataConfig', 's3Uri')
          unless output_uri
            status = parse_batch_status(job['status'], completed: TERMINAL.include?(job['status']))
            return [] if %i[failed cancelled].include?(status)

            raise Error, 'bedrock batch has no S3 output URI yet'
          end

          outputs = @provider.list_file_uris(output_uri)
                             .grep(/\.jsonl\.out\z/)
                             .reject { |uri| uri.end_with?('/manifest.json.out') }
                             .map { |uri| @provider.download_file(uri) }
          parse_bedrock_outputs(outputs, model: job['modelId'])
        end

        private

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

        def bedrock_job_name(input_uri, **)
          "ruby-llm-#{Digest::SHA256.hexdigest(input_uri)[0, 16]}"
        end

        def bedrock_job_url(id)
          "/model-invocation-job/#{URI.encode_www_form_component(id)}"
        end

        def parse_batch_response(data)
          status = data['status']
          {
            id: data['jobArn'] || data['jobIdentifier'],
            raw_status: status,
            completed: TERMINAL.include?(status),
            request_counts: bedrock_request_counts(data)
          }
        end

        def parse_batch_status(raw_status, completed:)
          return :pending unless completed
          return :succeeded if %w[Completed PartiallyCompleted].include?(raw_status)
          return :cancelled if raw_status == 'Stopped'

          :failed
        end

        def bedrock_request_counts(data)
          {
            'submitted' => data['submitTime'],
            'completed' => data['endTime']
          }.compact
        end
      end
    end
  end
end

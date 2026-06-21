# frozen_string_literal: true

module RubyLLM
  module Providers
    class Bedrock
      # S3-backed file storage for Bedrock batch input and output.
      class Files < UploadedFile::Protocol
        def upload(file, uri: nil, filename: nil, content_type: nil, **)
          attachment = file_attachment(file, filename:)
          target_uri = uri || storage_uri_for(attachment)
          bucket, key = parse_s3_uri(target_uri)

          with_file_body(attachment) do |body|
            s3_client.put_object(bucket: bucket, key: key, body: body,
                                 content_type: content_type || file_content_type(attachment))
          end

          uploaded_file(
            { 'uri' => target_uri },
            id: target_uri,
            uri: target_uri,
            filename: attachment.filename,
            byte_size: file_size(attachment),
            mime_type: content_type || file_content_type(attachment)
          )
        end

        def find(file_id)
          bucket, key = parse_s3_uri(file_id)
          response = s3_client.head_object(bucket: bucket, key: key)

          uploaded_file(
            { 'uri' => file_id },
            id: file_id,
            uri: file_id,
            filename: File.basename(key),
            byte_size: response.content_length,
            created_at: response.last_modified,
            mime_type: response.content_type
          )
        end

        def download(file_id)
          bucket, key = parse_s3_uri(file_id)
          s3_client.get_object(bucket: bucket, key: key).body.read
        end

        def list_uris(prefix_uri)
          bucket, prefix = parse_s3_uri(prefix_uri)
          uris = []
          token = nil

          loop do
            options = { bucket: bucket, prefix: prefix }
            options[:continuation_token] = token if token
            response = s3_client.list_objects_v2(**options)
            uris.concat(Array(response.contents).map { |object| "s3://#{bucket}/#{object.key}" })
            token = response.next_continuation_token
            break unless token
          end

          uris
        end

        private

        def storage_uri_for(attachment)
          base = @config.bedrock_batch_s3_uri.to_s.sub(%r{/+\z}, '')
          raise ConfigurationError, 'Set bedrock_batch_s3_uri to an s3:// bucket prefix' if base.empty?

          "#{base}/ruby_llm_uploads/#{SecureRandom.hex(8)}/#{attachment.filename}"
        end

        def s3_client
          require 'aws-sdk-s3'

          ::Aws::S3::Client.new(
            access_key_id: @config.bedrock_api_key,
            secret_access_key: @config.bedrock_secret_key,
            session_token: @config.bedrock_session_token,
            region: @config.bedrock_region
          )
        rescue LoadError
          raise Error, 'The aws-sdk-s3 gem is required for Bedrock file uploads. ' \
                       'Please add it to your Gemfile: gem "aws-sdk-s3"'
        end

        def parse_s3_uri(uri)
          parsed = URI(uri)
          raise ArgumentError, "Expected an s3:// URI, got: #{uri}" unless parsed.scheme == 's3'

          [parsed.host, parsed.path.delete_prefix('/')]
        end
      end
    end
  end
end

# frozen_string_literal: true

module RubyLLM
  module Providers
    class VertexAI
      # Google Cloud Storage-backed files for Vertex AI batch input and output.
      class Files < UploadedFile::Protocol
        def upload(file, uri: nil, filename: nil, content_type: nil, **)
          attachment = file_attachment(file, filename:)
          target_uri = uri || storage_uri_for(attachment)
          bucket_name, key = parse_gcs_uri(target_uri)

          with_file_body(attachment) do |body|
            bucket(bucket_name).create_file(body, key, content_type: content_type || file_content_type(attachment))
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
          bucket_name, key = parse_gcs_uri(file_id)
          object = bucket(bucket_name).file(key)
          raise Error, "GCS object not found: #{file_id}" unless object

          uploaded_file(
            { 'uri' => file_id },
            id: file_id,
            uri: file_id,
            filename: File.basename(key),
            byte_size: object.size,
            created_at: object.created_at,
            mime_type: object.content_type
          )
        end

        def download(file_id)
          bucket_name, key = parse_gcs_uri(file_id)
          object = bucket(bucket_name).file(key)
          raise Error, "GCS object not found: #{file_id}" unless object

          object.download.string
        end

        def list_uris(prefix_uri)
          bucket_name, prefix = parse_gcs_uri(prefix_uri)
          uris = []
          bucket(bucket_name).files(prefix: prefix).all do |object|
            uris << "gs://#{bucket_name}/#{object.name}"
          end
          uris
        end

        private

        def storage_uri_for(attachment)
          base = @config.vertexai_batch_gcs_uri.to_s.sub(%r{/+\z}, '')
          raise ConfigurationError, 'Set vertexai_batch_gcs_uri to a gs:// bucket prefix' if base.empty?

          "#{base}/ruby_llm_uploads/#{SecureRandom.hex(8)}/#{attachment.filename}"
        end

        def storage
          require 'google/cloud/storage'

          options = { project_id: @config.vertexai_project_id }
          if @config.vertexai_service_account_key
            options[:credentials] =
              JSON.parse(@config.vertexai_service_account_key)
          end
          ::Google::Cloud::Storage.new(**options)
        rescue LoadError
          raise Error, 'The google-cloud-storage gem is required for Vertex AI file uploads. ' \
                       'Please add it to your Gemfile: gem "google-cloud-storage"'
        end

        def bucket(name)
          storage.bucket(name) || raise(Error, "GCS bucket not found: #{name}")
        end

        def parse_gcs_uri(uri)
          parsed = URI(uri)
          raise ArgumentError, "Expected a gs:// URI, got: #{uri}" unless parsed.scheme == 'gs'

          [parsed.host, parsed.path.delete_prefix('/')]
        end
      end
    end
  end
end

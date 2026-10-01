# frozen_string_literal: true

module RubyLLM
  module Protocols
    module VertexAI
      # Google Cloud Storage-backed files for Vertex AI batch input and output.
      class Files < Protocols::Files
        # GCS object names allow spaces and other characters URI() rejects.
        GCS_URI = %r{\Ags://([^/]+)/?(.*)\z}m

        STORAGE_CLIENTS = Support::ProcessCache.new

        def self.storage_clients
          STORAGE_CLIENTS
        end

        # rubocop:disable-next Lint/UnusedMethodArgument
        def upload(file, filename: nil, purpose: nil, expires_in: nil, uri: nil, content_type: nil,
                   provider_options: {})
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

          STORAGE_CLIENTS.fetch(storage_key) { ::Google::Cloud::Storage.new(**storage_options) }
        rescue LoadError
          raise Error, 'The google-cloud-storage gem is required for Vertex AI file uploads. ' \
                       'Please add it to your Gemfile: gem "google-cloud-storage"'
        end

        # Without a key, Cloud Storage resolves its own credentials, including
        # settings of its own such as STORAGE_KEYFILE.
        def storage_options
          options = { project_id: @config.vertexai_project_id }
          options[:credentials] = @provider.google_credentials if @config.vertexai_service_account_key
          options
        end

        # A client keeps the credentials, scope, endpoint, and settings it was
        # built with, so only callers that would build the same one share it.
        def storage_key
          settings = ::Google::Cloud::Storage.configure
          [
            storage_options,
            settings.fields!.to_h { |field| [field, settings[field]] },
            ::Google::Cloud.configure.credentials,
            ENV.values_at(*credential_variables)
          ]
        end

        def credential_variables
          storage = ::Google::Cloud::Storage::Credentials
          loader = ::Google::Auth::CredentialsLoader
          storage::PATH_ENV_VARS + storage::JSON_ENV_VARS +
            loader.constants.grep(/_VAR\z/).map { |name| loader.const_get(name) }
        end

        def bucket(name)
          storage.bucket(name) || raise(Error, "GCS bucket not found: #{name}")
        end

        def parse_gcs_uri(uri)
          match = GCS_URI.match(uri.to_s)
          raise ArgumentError, "Expected a gs:// URI, got: #{uri}" unless match

          [match[1], match[2]]
        end
      end
    end
  end
end

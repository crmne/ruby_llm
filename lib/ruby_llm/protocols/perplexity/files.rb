# frozen_string_literal: true

module RubyLLM
  module Protocols
    module Perplexity
      # Perplexity's two kinds of stored file: batch input and output under
      # /v1/files, and files an Agent response generated, which belong to it
      # and are named response_id/files/file_id.
      class Files < Protocols::OpenAI::Files
        STORED_FILE_ID = /\A[A-Za-z0-9_-]+\z/
        RESPONSE_FILE_ID = %r{\A([A-Za-z0-9_-]+)/files/([A-Za-z0-9_-]+)\z}
        private_constant :STORED_FILE_ID, :RESPONSE_FILE_ID

        def find(resource_id)
          response_id, file_id = split_resource_id(resource_id)
          return super unless response_id

          response = @connection.get("v1/agent/#{response_id}/files")
          data = Array(response.body['data']).find { |item| item['id'] == file_id }
          raise Error.new('Perplexity response file was not found', response:) unless data

          parse_response_file(response_id, data)
        end

        def parse_response_file(response_id, data) # :nodoc:
          file_id = data['file_id'] || data.fetch('id')
          resource_id = "#{response_id}/files/#{file_id}"
          split_resource_id(resource_id)
          metadata = data.merge('response_id' => response_id)
          uploaded_file(metadata, id: resource_id, filename: data['filename'],
                                  byte_size: data['bytes'] || data['size_bytes'],
                                  created_at: timestamp(data['created_at']),
                                  mime_type: data['content_type'] || data['mime_type'], downloadable: true)
        end

        private

        def files_url
          'v1/files'
        end

        def download_file_url(resource_id)
          split_resource_id(resource_id) ? "v1/agent/#{resource_id}/content" : super
        end

        def split_resource_id(resource_id)
          id = resource_id.to_s
          return if id.match?(STORED_FILE_ID)

          match = id.match(RESPONSE_FILE_ID)
          return match.captures if match

          raise ArgumentError, 'Perplexity file IDs must be a file id or response_id/files/file_id'
        end
      end
    end
  end
end

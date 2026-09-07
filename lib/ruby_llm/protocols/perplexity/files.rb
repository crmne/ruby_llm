# frozen_string_literal: true

module RubyLLM
  module Protocols
    module Perplexity
      # Generated files belonging to a Perplexity Agent response.
      class Files < Protocols::Files
        def upload(*)
          raise Error, 'Perplexity Agent only supports downloading generated response files'
        end

        def find(resource_id)
          response_id, file_id = split_resource_id(resource_id)
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

        def download_file_url(resource_id)
          split_resource_id(resource_id)
          "v1/agent/#{resource_id}/content"
        end

        def split_resource_id(resource_id)
          match = resource_id.to_s.match(%r{\A([A-Za-z0-9_-]+)/files/([A-Za-z0-9_-]+)\z})
          return match.captures if match

          raise ArgumentError, 'Perplexity file IDs must include their response: response_id/files/file_id'
        end
      end
    end
  end
end

# frozen_string_literal: true

module RubyLLM
  module Protocols
    class Anthropic
      # Anthropic beta Files API.
      class Files < Protocols::Files
        BETA_HEADER = 'files-api-2025-04-14'

        def rejected_options(operation)
          operation == :upload ? %i[purpose uri] : super
        end

        private

        def files_url
          'v1/files'
        end

        def render_upload_fields(_attachment, expires_in: nil, **)
          { expires_in_seconds: expires_in }
        end

        def upload_headers(request)
          file_headers(request)
        end

        def file_headers(request)
          request.headers['anthropic-beta'] = BETA_HEADER
        end

        def parse_file_response(data)
          uploaded_file(
            data,
            id: data['id'],
            filename: data['filename'],
            byte_size: data['size_bytes'],
            created_at: timestamp(data['created_at']),
            expires_at: timestamp(data['expires_at']),
            mime_type: data['mime_type'],
            downloadable: data['downloadable']
          )
        end
      end
    end
  end
end

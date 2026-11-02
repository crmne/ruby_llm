# frozen_string_literal: true

module RubyLLM
  module Protocols
    module OpenAI
      # OpenAI Files API.
      class Files < Protocols::Files
        def rejected_options(operation)
          operation == :upload ? %i[uri] : super
        end

        private

        def render_upload_fields(_attachment, purpose: nil, expires_in: nil)
          { purpose:, expires_after: expires_after(expires_in) }
        end

        def expires_after(expires_in)
          { anchor: 'created_at', seconds: expires_in } if expires_in
        end

        def parse_upload_response(data, attachment)
          parse_file_response(data, mime_type: file_content_type(attachment))
        end

        def parse_file_response(data, mime_type: nil)
          uploaded_file(
            data,
            id: data['id'],
            filename: data['filename'],
            byte_size: data['bytes'],
            created_at: timestamp(data['created_at']),
            expires_at: timestamp(data['expires_at']),
            status: data['status'],
            purpose: data['purpose'],
            mime_type:
          )
        end
      end
    end
  end
end

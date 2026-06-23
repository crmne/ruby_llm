# frozen_string_literal: true

module RubyLLM
  module Providers
    class XAI
      # xAI Files API.
      class Files < UploadedFile::Protocol
        private

        def render_upload_payload(attachment, expires_after: nil, purpose: nil, **)
          multipart_payload(attachment, expires_after:, purpose:)
        end

        def parse_file_response(data)
          uploaded_file(
            data,
            id: data['id'],
            filename: data['filename'],
            byte_size: data['bytes'],
            created_at: timestamp(data['created_at']),
            expires_at: timestamp(data['expires_at']),
            purpose: data['purpose']
          )
        end
      end
    end
  end
end

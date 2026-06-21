# frozen_string_literal: true

module RubyLLM
  module Providers
    class Mistral
      # Mistral Files API.
      class Files < UploadedFile::Protocol
        private

        def download_file_url(file_id)
          "#{file_info_url(file_id)}/download"
        end

        def render_upload_payload(attachment, purpose: nil, expiry: nil, visibility: nil, **)
          multipart_payload(attachment, purpose:, expiry:, visibility:)
        end

        def parse_file_response(data)
          uploaded_file(
            data,
            id: data['id'],
            filename: data['filename'],
            byte_size: data['bytes'],
            created_at: timestamp(data['created_at']),
            expires_at: timestamp(data['expires_at']),
            mime_type: data['mimetype'],
            purpose: data['purpose'],
            status: data['deleted'] ? 'deleted' : nil
          )
        end
      end
    end
  end
end

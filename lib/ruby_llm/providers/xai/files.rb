# frozen_string_literal: true

module RubyLLM
  module Providers
    class XAI
      # xAI Files API.
      class Files < UploadedFile::Protocol
        private

        # rubocop:disable Lint/UnusedMethodArgument, Metrics/ParameterLists
        def render_upload_payload(attachment, purpose: nil, expires_in: nil, visibility: nil,
                                  display_name: nil, uri: nil, content_type: nil)
          multipart_payload(attachment, expires_after: expires_in, purpose:)
        end
        # rubocop:enable Lint/UnusedMethodArgument, Metrics/ParameterLists

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

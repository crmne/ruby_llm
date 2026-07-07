# frozen_string_literal: true

module RubyLLM
  module Protocols
    module OpenAI
      # OpenAI Files API.
      class Files < UploadedFile::Protocol
        UPLOAD_PURPOSES = %w[assistants batch fine-tune vision user_data evals].freeze

        private

        # rubocop:disable Lint/UnusedMethodArgument, Metrics/ParameterLists
        def render_upload_payload(attachment, purpose: nil, expires_in: nil, visibility: nil,
                                  display_name: nil, uri: nil, content_type: nil)
          unless purpose
            raise ArgumentError, "#{@provider.name} file uploads require purpose: " \
                                 "#{UPLOAD_PURPOSES.join(', ')}"
          end

          multipart_payload(attachment, purpose:, expires_after: expires_after(expires_in))
        end
        # rubocop:enable Lint/UnusedMethodArgument, Metrics/ParameterLists

        def expires_after(expires_in)
          { anchor: 'created_at', seconds: expires_in } if expires_in
        end

        def parse_file_response(data)
          uploaded_file(
            data,
            id: data['id'],
            filename: data['filename'],
            byte_size: data['bytes'],
            created_at: timestamp(data['created_at']),
            expires_at: timestamp(data['expires_at']),
            status: data['status'],
            purpose: data['purpose']
          )
        end
      end
    end
  end
end

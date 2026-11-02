# frozen_string_literal: true

module RubyLLM
  module Protocols
    module Mistral
      # Mistral Files API.
      class Files < Protocols::Files
        def rejected_options(operation)
          operation == :upload ? %i[uri] : super
        end

        private

        def render_upload_fields(_attachment, purpose: nil, expires_in: nil)
          { purpose:, expiry: expiry_hours(expires_in) }
        end

        def expiry_hours(expires_in)
          expires_in&.fdiv(3600)&.ceil
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

# frozen_string_literal: true

module RubyLLM
  module Providers
    class OpenRouter
      # OpenRouter Files API.
      class Files < UploadedFile::Protocol
        private

        def parse_file_response(data)
          uploaded_file(
            data,
            id: data['id'],
            filename: data['filename'],
            byte_size: data['size_bytes'],
            created_at: timestamp(data['created_at']),
            mime_type: data['mime_type'],
            downloadable: data['downloadable']
          )
        end
      end
    end
  end
end

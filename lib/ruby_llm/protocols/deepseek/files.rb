# frozen_string_literal: true

module RubyLLM
  module Protocols
    module DeepSeek
      # DeepSeek stores image files for reuse by vision models.
      class Files < Protocols::OpenAI::Files
        IMAGE_TYPES = %w[image/jpeg image/png image/gif image/webp].freeze
        MAX_FILE_SIZE = 64 * 1024 * 1024

        def download(_file_id)
          raise Error, 'DeepSeek does not support downloading uploaded files'
        end

        private

        def render_upload_payload(attachment, purpose: nil, **options)
          raise UnsupportedAttachmentError, attachment.mime_type unless IMAGE_TYPES.include?(attachment.mime_type)
          raise ArgumentError, 'DeepSeek image uploads cannot exceed 64 MiB' if file_size(attachment) > MAX_FILE_SIZE
          raise ArgumentError, 'DeepSeek file uploads require purpose: user_data' if purpose && purpose != 'user_data'

          super(attachment, purpose: 'user_data', **options)
        end

        def uploaded_file(data, **attributes)
          super(data, **attributes, downloadable: false)
        end
      end
    end
  end
end

# frozen_string_literal: true

module RubyLLM
  module Protocols
    module DeepSeek
      # DeepSeek stores image files for reuse by vision models.
      class Files < Protocols::OpenAI::Files
        def download(_file_id)
          raise Error, 'DeepSeek does not support downloading uploaded files'
        end

        private

        def render_upload_payload(attachment, purpose: nil, **options)
          super(attachment, purpose: purpose || 'user_data', **options)
        end

        def uploaded_file(data, **attributes)
          super(data, **attributes, downloadable: false)
        end
      end
    end
  end
end

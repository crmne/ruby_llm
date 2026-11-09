# frozen_string_literal: true

module RubyLLM
  module Protocols
    module Moonshot
      # Kimi's Files API. A file's purpose decides what Kimi does with it, so
      # an upload without one follows its content: images and videos are
      # stored for the models to read, and everything else has its text
      # extracted.
      class Files < Protocols::OpenAI::Files
        def rejected_options(operation)
          operation == :upload ? %i[expires_in uri] : super
        end

        # Kimi wraps a file's extracted text in a JSON object; any other
        # stored file comes back as it was written.
        def download(file_id)
          body = super
          extracted_text(body) || body
        end

        private

        def render_upload_fields(attachment, purpose: nil, **)
          super(attachment, purpose: purpose || default_purpose(attachment))
        end

        def default_purpose(attachment)
          return 'image' if attachment.image?
          return 'video' if attachment.video?

          'file-extract'
        end

        def parse_file_response(data, mime_type: nil)
          super(data, mime_type: mime_type || data['file_type'])
        end

        def extracted_text(body)
          data = JSON.parse(body)
          data['content'] if data.is_a?(Hash) && data['type'] == 'file'
        rescue JSON::ParserError
          nil
        end
      end
    end
  end
end

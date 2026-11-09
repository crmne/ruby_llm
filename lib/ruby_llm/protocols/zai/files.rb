# frozen_string_literal: true

module RubyLLM
  module Protocols
    module ZAI
      # Z.ai file storage. Files go up and can be referenced by id, but Z.ai
      # has no route that reads one back, and no expiry option.
      class Files < Protocols::OpenAI::Files
        def rejected_options(operation)
          operation == :upload ? %i[expires_in uri] : super
        end

        def find(_file_id)
          raise Error, 'Z.ai does not support retrieving uploaded files'
        end

        def download(_file_id)
          raise Error, 'Z.ai does not support downloading uploaded files'
        end

        private

        def render_upload_fields(_attachment, purpose: nil, **)
          { purpose: purpose || 'user_data' }
        end

        def timestamp(value)
          Time.at(value.fdiv(1000)) if value
        end

        def uploaded_file(data, **attributes)
          super(data, **attributes, downloadable: false)
        end
      end
    end
  end
end

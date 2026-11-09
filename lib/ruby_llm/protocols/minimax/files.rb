# frozen_string_literal: true

module RubyLLM
  module Protocols
    class MiniMax
      # MiniMax's Files API, which requires a purpose on every upload.
      class Files < Protocols::Files
        INPUT_PURPOSES = %w[voice_clone prompt_audio t2a_async_input video_understanding video_generation_input].freeze

        def rejected_options(operation)
          operation == :upload ? %i[uri expires_in] : super
        end

        private

        def files_url
          media_url('v1/files/upload')
        end

        def file_info_url(file_id)
          media_url("v1/files/retrieve?file_id=#{URI.encode_uri_component(file_id.to_s)}")
        end

        def download_file_url(file_id)
          media_url("v1/files/retrieve_content?file_id=#{URI.encode_uri_component(file_id.to_s)}")
        end

        def media_url(path)
          "#{@provider.media_base}/#{path}"
        end

        def render_upload_fields(_attachment, purpose: nil, **)
          { purpose: }
        end

        def parse_upload_response(data, attachment)
          parse_file_response(data, mime_type: file_content_type(attachment))
        end

        def parse_file_response(data, mime_type: nil)
          file = data['file']
          raise Error, 'MiniMax did not return a file' unless file

          uploaded_file(
            data,
            id: file['file_id'].to_s,
            filename: file['filename'],
            byte_size: file['bytes'],
            created_at: timestamp(file['created_at']),
            purpose: file['purpose'],
            downloadable: !INPUT_PURPOSES.include?(file['purpose']),
            mime_type:
          )
        end
      end
    end
  end
end

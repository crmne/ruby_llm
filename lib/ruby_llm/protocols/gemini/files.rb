# frozen_string_literal: true

module RubyLLM
  module Protocols
    class Gemini
      # Gemini Files API.
      class Files < UploadedFile::Protocol
        def upload(file, filename: nil, display_name: nil, **)
          attachment = file_attachment(file, filename:)
          upload_url = start_resumable_upload(attachment, display_name: display_name || attachment.filename)
          response = upload_file_bytes(upload_url, attachment)
          parse_file_response(response.body.fetch('file'))
        end

        def download(file_id)
          file = find(file_id)
          download_uri = file.metadata['downloadUri']
          raise Error, 'gemini file has no download URI' unless download_uri

          gemini_connection(request_json: false, response_json: false).get(download_uri) do |request|
            request.headers.merge!(@provider.headers)
          end.body
        end

        private

        def file_info_url(file_id)
          gemini_file_name(file_id)
        end

        def start_resumable_upload(attachment, display_name:)
          response = gemini_connection(request_json: true, response_json: true).post(gemini_upload_url) do |request|
            request.headers.merge!(@provider.headers)
            request.headers['X-Goog-Upload-Protocol'] = 'resumable'
            request.headers['X-Goog-Upload-Command'] = 'start'
            request.headers['X-Goog-Upload-Header-Content-Length'] = attachment.content.bytesize.to_s
            request.headers['X-Goog-Upload-Header-Content-Type'] = file_content_type(attachment)
            request.headers['Content-Type'] = 'application/json'
            request.body = { file: { display_name: display_name } }
          end

          response.headers['x-goog-upload-url'] || response.headers['X-Goog-Upload-URL'] ||
            raise(Error, 'gemini did not return an upload URL')
        end

        def upload_file_bytes(upload_url, attachment)
          gemini_connection(request_json: false, response_json: true).post(upload_url) do |request|
            request.headers.merge!(@provider.headers)
            request.headers['Content-Length'] = attachment.content.bytesize.to_s
            request.headers['X-Goog-Upload-Offset'] = '0'
            request.headers['X-Goog-Upload-Command'] = 'upload, finalize'
            request.body = attachment.content
          end
        end

        def parse_file_response(data)
          uploaded_file(
            data,
            id: data['name'],
            filename: data['displayName'],
            byte_size: data['sizeBytes']&.to_i,
            created_at: timestamp(data['createTime']),
            expires_at: timestamp(data['expirationTime']),
            mime_type: data['mimeType'],
            status: data['state'],
            uri: data['uri']
          )
        end

        def gemini_file_name(file_id)
          file_id.to_s.start_with?('files/') ? file_id : "files/#{file_id}"
        end

        def gemini_upload_url
          base = @provider.api_base.to_s.sub(%r{/+\z}, '')
          "#{base.sub(%r{/v1beta\z}, '/upload/v1beta').sub(%r{/v1\z}, '/upload/v1')}/files"
        end

        def gemini_connection(request_json:, response_json:)
          connection = Connection.basic do |connection|
            connection.request :json if request_json
            connection.response :json if response_json
            connection.adapter @config.faraday_adapter
            connection.use :llm_errors, provider: @provider
          end
          connection.url_prefix = @provider.api_base
          connection
        end
      end
    end
  end
end

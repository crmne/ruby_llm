# frozen_string_literal: true

module RubyLLM
  module Providers
    class Gemini
      # Service for uploading large files to Gemini's Files API
      class FileUploadService
        MAX_POLL_TIME = 60
        POLLING_INTERVAL = 2

        attr_reader :config

        def initialize(_connection, config)
          @config = config
          @faraday = Faraday.new(url: api_base) do |f|
            f.headers['x-goog-api-key'] = @config.gemini_api_key
            f.request :json
            f.response :json
            f.adapter :net_http
          end
        end

        def upload(attachment)
          upload_id = initiate_upload(attachment)
          file_uri = upload_file_content(attachment, upload_id)
          wait_for_processing(file_uri)
          file_uri
        end

        private

        def api_base
          @config.gemini_api_base || 'https://generativelanguage.googleapis.com'
        end

        def initiate_upload(attachment)
          response = @faraday.post('upload/v1beta/files') do |req|
            req.headers = req.headers.merge(
              'X-Goog-Upload-Protocol' => 'resumable',
              'X-Goog-Upload-Command' => 'start',
              'X-Goog-Upload-Header-Content-Length' => attachment.size.to_s,
              'X-Goog-Upload-Header-Content-Type' => attachment.mime_type
            )
            req.body = {
              file: {
                display_name: attachment.filename
              }
            }.to_json
          end
          response.headers['x-guploader-uploadid']
        end

        def upload_file_content(attachment, upload_id)
          response = @faraday.post('upload/v1beta/files') do |req|
            req.params = req.params.merge(
              'upload_id' => upload_id,
              'upload_protocol' => 'resumable'
            )
            req.headers = req.headers.merge(
              'Content-Length' => attachment.size.to_s,
              'X-Goog-Upload-Offset' => '0',
              'X-Goog-Upload-Command' => 'upload, finalize'
            )
            req.body = File.binread(attachment.source)
          end
          response.body['file']['uri']
        end

        def wait_for_processing(file_uri)
          file_id = file_uri.split('/').last

          start_time = Time.now
          while Time.now - start_time < MAX_POLL_TIME
            response = @faraday.get("v1beta/files/#{file_id}")
            status = response.body['state']
            return if status == 'ACTIVE'

            sleep POLLING_INTERVAL
          end

          raise TimeoutError, "File processing timeout after #{MAX_POLL_TIME}s"
        end

        class TimeoutError < StandardError; end
      end
    end
  end
end

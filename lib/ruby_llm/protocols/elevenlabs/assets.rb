# frozen_string_literal: true

module RubyLLM
  module Protocols
    class ElevenLabs
      # Workspace media assets used by the Image & Video API.
      class Assets < Protocols::Files
        def download(file_id)
          file = find(file_id)
          url = file.metadata['content_url']
          raise Error, 'ElevenLabs asset is still processing; retrieve it again before downloading' unless url

          Transport::Connection.download(url, @config)
        end

        private

        def files_url
          'v1/assets'
        end

        def upload_file_field
          :asset
        end

        def render_upload_fields(attachment, **)
          { name: attachment.filename }
        end

        def parse_file_response(data)
          uploaded_file(data, id: data.fetch('asset_id'), filename: data['name'], mime_type: data['mime_type'],
                              created_at: timestamp(data['created_at_unix']), downloadable: true,
                              status: data['content_url'] ? 'ready' : 'processing')
        end
      end
    end
  end
end

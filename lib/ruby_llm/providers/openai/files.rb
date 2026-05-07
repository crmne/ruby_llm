# frozen_string_literal: true

module RubyLLM
  module Providers
    class OpenAI
      # Files methods of the OpenAI API integration
      module Files
        def files_url
          'files'
        end

        def file_info_url(file_id)
          "#{files_url}/#{file_id}"
        end

        def download_file_url(file_id)
          "#{file_info_url(file_id)}/content"
        end

        def render_file_payload(file, purpose:, expires_after: nil)
          {
            file: build_file(file),
            purpose: purpose,
            expires_after: expires_after
          }.compact
        end

        def parse_file_response(response)
          data = response.body

          ProviderFile.new(
            id: data['id'],
            filename: data['filename'],
            byte_size: data['bytes'],
            created_at: Time.at(data['created_at'])
          )
        end

        module_function

        def build_file(file)
          attachment = file.is_a?(Attachment) ? file : Attachment.new(file)

          upload_source = if attachment.path?
                            attachment.source.to_s
                          elsif attachment.io_like?
                            attachment.source.tap { |io| io.rewind if io.respond_to?(:rewind) }
                          else
                            StringIO.new(attachment.content)
                          end

          Faraday::UploadIO.new(upload_source, attachment.mime_type, attachment.filename)
        end
      end
    end
  end
end

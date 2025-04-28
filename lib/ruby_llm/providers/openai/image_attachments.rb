# frozen_string_literal: true

require 'open-uri' # Added for fetching URLs

module RubyLLM
  module Providers
    module OpenAI
      class ImageAttachments
        def initialize(sources)
          @sources = Array(sources)
        end

        def format
          @sources.map do |source|
            source.start_with?('http') ? from_remote_url(source) : from_local_file(source)
          end
        end

        private

        def mime_type_for_image(path)
          ext = File.extname(path).downcase.delete('.')
          case ext
          when 'png' then 'image/png'
          when 'gif' then 'image/gif'
          when 'webp' then 'image/webp'
          else 'image/jpeg'
          end
        end

        def from_local_file(source)
          Faraday::UploadIO.new(source, mime_type_for_image(source), File.basename(source))
        end

        def from_remote_url(source)
          parsed_uri = URI.parse(source)

          # Fetch the remote content or open local file. URI.open returns an IO-like object (StringIO or Tempfile)
          io = parsed_uri.open
          content_type = io.content_type # Get MIME type from the response headers or guess for local files

          # Extract filename from path, provide fallback
          filename = File.basename(parsed_uri.path)
          Faraday::UploadIO.new(io, content_type, filename)
          # NOTE: Do NOT close the IO stream here. Faraday will handle it.
        end
      end
    end
  end
end

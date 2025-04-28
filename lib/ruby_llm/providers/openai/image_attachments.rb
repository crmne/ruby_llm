# frozen_string_literal: true

require 'open-uri' # Added for fetching URLs
require 'faraday/multipart'

module RubyLLM
  module Providers
    module OpenAI
      class ImageAttachments
        def initialize(sources)
          @sources = Array(sources)
        end

        def format
          @sources.map do |source|
            faraday_multipart_format(source)
          end
        end

        private

        def faraday_multipart_format(source)
          io = nil # Define io outside the begin block
          begin
            # Parse the URI first to handle potential parsing errors
            parsed_uri = URI.parse(source)

            # Fetch the remote content. URI.open returns an IO-like object (StringIO or Tempfile)
            io = parsed_uri.open
            content_type = io.content_type # Get MIME type from the response headers

            # Extract filename from path, provide fallback
            filename = File.basename(parsed_uri.path)
            # Create the FilePart with the IO object, determined content type, and filename
            Faraday::Multipart::FilePart.new(io, content_type, filename)
          ensure
            # Ensure the temporary file descriptor from URI.open is closed if it exists
            io&.close if io.respond_to?(:close) && !io.closed?
          end
        end
      end
    end
  end
end

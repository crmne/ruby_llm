# frozen_string_literal: true

module RubyLLM
  # A module for handling attachments and file operations in RubyLLM.
  module Attachments
    # Base class for attachments
    class Base
      attr_reader :source, :filename

      def initialize(source, filename: nil)
        @source = source
        @filename = filename ||
                    (@source.respond_to?(:original_filename) && @source.original_filename) ||
                    (@source.respond_to?(:path) && File.basename(@source.path)) ||
                    (@source.is_a?(String) && File.basename(@source.split('?').first)) || # Basic URL basename
                    nil
      end

      def url?
        @source.is_a?(String) && @source.match?(%r{^https?://})
      end

      def file_path?
        @source.is_a?(String) && !url?
      end

      def io_like?
        @source.respond_to?(:read) && !file_path?
      end

      def content
        return @content if defined?(@content) && !@content.nil?

        if url?
          fetch_content
        elsif file_path?
          load_content_from_path
        elsif io_like?
          load_content_from_io
        else
          RubyLLM.logger.warn "Attachment source is neither a String nor an IO-like object: #{@source}"
          nil
        end

        @content
      end

      def type
        self.class.name.demodulize.downcase
      end

      def encoded
        Base64.strict_encode64(content)
      end

      def text?
        content.is_a?(String) || RubyLLM::MimeTypes.text?(mime_type)
      end

      def mime_type
        RubyLLM::MimeTypes.detect_from_path(@filename)
      end

      private

      def fetch_content
        RubyLLM.logger.debug("Fetching content from URL: #{@source}")
        response = Faraday.get(@source)
        @content = response.body if response.success?
      end

      def load_content_from_path
        @content = File.read(File.expand_path(@source))
      end

      def load_content_from_io
        @source.rewind if source.respond_to? :rewind
        @content = @source.read
      end
    end
  end
end

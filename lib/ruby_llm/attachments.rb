# frozen_string_literal: true

module RubyLLM
  # A module for handling attachments and file operations in RubyLLM.
  module Attachments
    # Base class for attachments
    class Base
      attr_reader :source

      def initialize(source)
        @source = source
      end

      def url?
        @source.is_a?(String) && @source.match?(%r{^https?://})
      end

      def file?
        @source.is_a?(String) && !url?
      end

      def content
        @content ||= load_content if file?
        @content ||= fetch_content if url?
        @content
      end

      def type
        self.class.name.demodulize.downcase
      end

      def encoded
        Base64.strict_encode64(content)
      end

      private

      def fetch_content
        RubyLLM.logger.debug("Fetching content from URL: #{@source}")
        Faraday.get(@source).body if url?
      end

      def load_content
        File.read(File.expand_path(@source)) if file?
      end
    end
  end
end

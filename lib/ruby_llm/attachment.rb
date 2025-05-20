# frozen_string_literal: true

module RubyLLM
  # A class representing a file attachment.
  class Attachment
    attr_reader :source, :filename, :mime_type

    def initialize(source, filename: nil)
      @source = source
      if url?
        @source = URI source
        @filename = filename || File.basename(@source.path).to_s
      elsif path?
        @source = Pathname.new source
        @filename = filename || @source.basename.to_s
      else
        @filename = filename
      end

      @mime_type = RubyLLM::MimeType.for @source, name: @filename
      @mime_type = RubyLLM::MimeType.for content if @mime_type == 'application/octet-stream'
    end

    def url?
      @source.is_a?(URI) || (@source.is_a?(String) && @source.match?(%r{^https?://}))
    end

    def path?
      @source.is_a?(Pathname) || (@source.is_a?(String) && !url?)
    end

    def io_like?
      @source.respond_to?(:read) && !path?
    end

    def content
      return @content if defined?(@content) && !@content.nil?

      if url?
        fetch_content
      elsif path?
        load_content_from_path
      elsif io_like?
        load_content_from_io
      else
        RubyLLM.logger.warn "Source is neither a URL, path, nor IO-like: #{@source.class}"
        nil
      end

      @content
    end

    def encoded
      Base64.strict_encode64(content)
    end

    def type
      return :image if image?
      return :audio if audio?
      return :pdf if pdf?

      :text
    end

    def image?
      RubyLLM::MimeType.image? mime_type
    end

    def audio?
      RubyLLM::MimeType.audio? mime_type
    end

    def pdf?
      RubyLLM::MimeType.pdf? mime_type
    end

    def text?
      RubyLLM::MimeType.text? mime_type
    end

    def to_h
      { type: a.type, source: a.source }
    end

    private

    def fetch_content
      response = Connection.basic.get @source.to_s
      @content = response.body
    end

    def load_content_from_path
      @content = File.read(@source)
    end

    def load_content_from_io
      @source.rewind if source.respond_to? :rewind
      @content = @source.read
    end
  end
end

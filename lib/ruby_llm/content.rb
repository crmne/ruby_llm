# frozen_string_literal: true

module RubyLLM
  # Represents the content sent to or received from an LLM.
  # Stores data in a standard internal format, letting providers
  # handle their own formatting needs.
  class Content
    def initialize(text = nil, attachments = {}) # rubocop:disable Metrics/AbcSize,Metrics/MethodLength
      @parts = []
      @parts << { type: 'text', text: text } unless text.nil? || text.empty?

      Array(attachments[:image]).each do |source|
        @parts << attach_image(source)
      end

      Array(attachments[:audio]).each do |source|
        @parts << attach_audio(source)
      end

      Array(attachments[:pdf]).each do |source|
        @parts << attach_pdf(source)
      end
    end

    def to_a
      return if @parts.empty?

      @parts
    end

    def format
      return @parts.first[:text] if @parts.size == 1 && @parts.first[:type] == 'text'

      to_a
    end

    private

    def attach_image(source) # rubocop:disable Metrics/MethodLength
      return source if source.is_a?(Hash)

      source = File.expand_path(source) unless source.start_with?('http')

      return { type: 'image', source: { url: source } } if source.start_with?('http')

      data = Base64.strict_encode64(File.read(source))
      mime_type = mime_type_for(source)

      {
        type: 'image',
        source: {
          type: 'base64',
          media_type: mime_type,
          data: data
        }
      }
    end

    def attach_audio(source)
      source = File.expand_path(source) unless source.start_with?('http')
      data = encode_file(source)
      format = File.extname(source).delete('.') || 'wav'

      {
        type: 'input_audio',
        input_audio: {
          data: data,
          format: format
        }
      }
    end

    def attach_pdf(source)
      source = File.expand_path(source) unless source.start_with?('http')

      pdf_data = {
        type: 'pdf',
        source: source
      }

      # For local files, validate they exist
      unless source.start_with?('http')
        raise Error, "PDF file not found: #{source}" unless File.exist?(source)

        # Preload file content for providers that need it
        pdf_data[:content] = File.read(source)
      end

      pdf_data
    end

    def encode_file(source)
      if source.start_with?('http')
        response = Faraday.get(source)
        Base64.strict_encode64(response.body)
      else
        Base64.strict_encode64(File.read(source))
      end
    end

    def mime_type_for(path)
      ext = File.extname(path).delete('.')
      "image/#{ext}"
    end
  end
end

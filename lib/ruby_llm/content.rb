# frozen_string_literal: true

module RubyLLM
  # Represents the content sent to or received from an LLM.
  # Stores data in a standard internal format, letting providers
  # handle their own formatting needs.
  class Content
    attr_reader :text, :attachments

    def initialize(text = nil, attachments = nil)
      @text = text
      @attachments = []

      process_attachments(attachments)
      raise ArgumentError, 'Text and attachments cannot be both nil' if @text.nil? && @attachments.empty?
    end

    def add_attachment(klass, source)
      props = extract_source_properties(source)
      @attachments << klass.new(props[:location], filename: props[:filename], mime_type: props[:mime_type])
      self
    end

    def add_image(source)
      add_attachment(Attachments::Image, source)
    end

    def add_audio(source)
      add_attachment(Attachments::Audio, source)
    end

    def add_pdf(source)
      add_attachment(Attachments::PDF, source)
    end

    def add_text(source)
      puts source
      add_attachment(Attachments::Text, source)
    end

    def format
      if @text && @attachments.empty?
        @text
      else
        self
      end
    end

    # For Rails serialization
    def as_json
      hash = { text: @text }
      unless @attachments.empty?
        hash[:attachments] = @attachments.map do |a|
          { type: a.type, source: a.source }
        end
      end
      hash
    end

    private

    def extract_source_properties(source)
      if source.is_a?(Hash) && Utils.hash_get(source, :location)
        {
          location: Utils.hash_get(source, :location),
          mime_type: Utils.hash_get(source, :mime_type),
          filename: Utils.hash_get(source, :filename)
        }
      else
        { location: source }
      end
    end

    def process_attachments_hash(attachments)
      return unless attachments.is_a?(Hash)

      Utils.to_safe_array(attachments[:image]).each { |source| add_image(source) }
      Utils.to_safe_array(attachments[:audio]).each { |source| add_audio(source) }
      Utils.to_safe_array(attachments[:pdf]).each { |source| add_pdf(source) }
      Utils.to_safe_array(attachments[:text]).each { |source| add_text(source) }
    end

    def process_attachments_array_or_string(attachments)
      Utils.to_safe_array(attachments).each do |file|
        props = extract_source_properties(file)

        if props[:mime_type]
          # Use explicitly provided MIME type
          add_attachment_by_mime_type(props[:location], props[:mime_type], props[:filename])
        else
          # Fall back to detection from path
          detect_and_add_attachment(props[:location])
        end
      end
    end

    def add_attachment_by_mime_type(source, mime_type, filename = nil)
      if RubyLLM::MimeTypes.image?(mime_type)
        add_image({ location: source, mime_type: mime_type, filename: filename })
      elsif RubyLLM::MimeTypes.audio?(mime_type)
        add_audio({ location: source, mime_type: mime_type, filename: filename })
      elsif RubyLLM::MimeTypes.pdf?(mime_type)
        add_pdf({ location: source, mime_type: mime_type, filename: filename })
      else
        add_text({ location: source, mime_type: mime_type, filename: filename })
      end
    end

    def detect_and_add_attachment(file)
      mime_type = RubyLLM::MimeTypes.detect_from_path(file.to_s)
      add_attachment_by_mime_type(file, mime_type)
    end

    def process_attachments(attachments)
      if attachments.is_a?(Hash)
        process_attachments_hash attachments
      else
        process_attachments_array_or_string attachments
      end
    end
  end
end

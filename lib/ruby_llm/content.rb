# frozen_string_literal: true

module RubyLLM
  # Represents the content sent to or received from an LLM.
  # Selects the appropriate attachment class based on the content type.
  class Content
    attr_reader :text, :attachments

    def initialize(text = nil, attachments = nil)
      @text = text
      @attachments = []

      process_attachments(attachments)
      raise ArgumentError, 'Text and attachments cannot be both nil' if @text.nil? && @attachments.empty?
    end

    def add_attachment(source)
      @attachments << Attachment.new(source)
      self
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
      { text: @text, attachments: @attachments.map(&:as_json) }
    end

    private

    def process_attachments_array_or_string(attachments)
      Utils.to_safe_array(attachments).each do |file|
        add_attachment(file)
      end
    end

    def process_attachments(attachments)
      if attachments.is_a?(Hash)
        # Ignores types (like :image, :audio, :text, :pdf) since we have robust MIME type detection
        attachments.each_value(&method(:process_attachments_array_or_string))
      else
        process_attachments_array_or_string attachments
      end
    end
  end
end

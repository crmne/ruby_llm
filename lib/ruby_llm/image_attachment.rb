# frozen_string_literal: true

module RubyLLM
  # A class representing a file attachment.
  class ImageAttachment < Attachment
    attr_reader :image, :content

    def initialize(data:, mime_type:, model_id:)
      super(nil, filename: nil)
      @image = Image.new(data:, mime_type:, model_id:)
      @content = data
    end

    def image?
      true
    end
  end
end

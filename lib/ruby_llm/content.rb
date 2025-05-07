# frozen_string_literal: true

module RubyLLM
  # Represents the content sent to or received from an LLM.
  # Stores data in a standard internal format, letting providers
  # handle their own formatting needs.
  class Content
    attr_reader :text, :attachments

    class << self
      def from_json(json)
        text = json.delete(:text)
        attachments = {}
        unless Array(json[:attachments]).empty?
          attachments = json[:attachments]
                        .group_by { |attachment| attachment[:type].to_sym }
                        .transform_values { |sources| sources.map { |a| a[:source] } }
        end

        new(text, attachments)
      end
    end

    def initialize(text = nil, attachments = {})
      @text = text
      @attachments = []

      process_attachments(attachments)
      raise ArgumentError, 'Text and attachments cannot be both nil' if @text.nil? && @attachments.empty?
    end

    def add_image(source)
      @attachments << Attachments::Image.new(source)
      self
    end

    def add_audio(source)
      @attachments << Attachments::Audio.new(source)
      self
    end

    def add_pdf(source)
      @attachments << Attachments::PDF.new(source)
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
      hash = { text: @text }
      unless @attachments.empty?
        hash[:attachments] = @attachments.map do |a|
          { type: a.type, source: a.source }
        end
      end
      hash
    end

    private

    def process_attachments(attachments)
      return unless attachments.is_a?(Hash)

      Array(attachments[:image]).each { |source| add_image(source) }
      Array(attachments[:audio]).each { |source| add_audio(source) }
      Array(attachments[:pdf]).each { |source| add_pdf(source) }
    end
  end
end

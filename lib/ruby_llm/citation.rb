# frozen_string_literal: true

module RubyLLM
  # A citation linking a span of generated text to the source material
  # that supports it, normalized across providers.
  class Citation
    attr_reader :url, :title, :cited_text, :text, :start_index, :end_index,
                :source_index, :start_page, :end_page

    def initialize(options = {})
      @url = options[:url]
      @title = options[:title]
      @cited_text = options[:cited_text]
      @text = options[:text]
      @start_index = options[:start_index]
      @end_index = options[:end_index]
      @source_index = options[:source_index]
      @start_page = options[:start_page]
      @end_page = options[:end_page]
    end

    def self.from_h(data)
      new(Utils.deep_symbolize_keys(data))
    end

    def to_h
      {
        url: url,
        title: title,
        cited_text: cited_text,
        text: text,
        start_index: start_index,
        end_index: end_index,
        source_index: source_index,
        start_page: start_page,
        end_page: end_page
      }.compact
    end

    def ==(other)
      other.is_a?(Citation) && to_h == other.to_h
    end
    alias eql? ==

    def hash
      to_h.hash
    end
  end
end

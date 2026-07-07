# frozen_string_literal: true

module RubyLLM
  # A Citation links a span of generated text to the source material that
  # supports it. Providers return citations in different shapes. RubyLLM
  # normalizes all of them into Citation objects on Message#citations.
  # Fields a provider does not report are +nil+.
  #
  #   chat = RubyLLM.chat(model: 'claude-sonnet-4-5').with_citations
  #   response = chat.ask "Who created Ruby?", with: "facts.txt"
  #
  #   response.citations.each do |citation|
  #     citation.title      # => "facts.txt"
  #     citation.cited_text # => the quoted passage from facts.txt
  #     citation.text       # => the span of the answer it supports
  #   end
  #
  class Citation
    # The URL of the cited source, when citing the web, or +nil+.
    attr_reader :url

    # The title or filename of the cited source, or +nil+.
    attr_reader :title

    # The quoted snippet from the source material, or +nil+.
    attr_reader :cited_text

    # The span of the response content this citation supports, or +nil+.
    attr_reader :text

    # The character offset where the cited span starts in the response
    # content, or +nil+.
    #
    #   response.content[citation.start_index...citation.end_index] == citation.text # => true
    #
    attr_reader :start_index

    # The character offset where the cited span ends in the response
    # content, or +nil+.
    attr_reader :end_index

    # The 0-indexed position of the source document or search result,
    # or +nil+.
    attr_reader :source_index

    # The first page of a PDF citation (1-indexed, inclusive), or +nil+.
    attr_reader :start_page

    # The last page of a PDF citation (1-indexed, inclusive), or +nil+.
    attr_reader :end_page

    def initialize(options = {}) # :nodoc:
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

    def self.from_h(data) # :nodoc:
      new(Utils.deep_symbolize_keys(data))
    end

    # Returns the citation as a Hash with symbol keys, omitting +nil+ fields.
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

    # Returns +true+ if +other+ is a Citation with the same attributes,
    # +false+ otherwise.
    def ==(other)
      other.is_a?(Citation) && to_h == other.to_h
    end
    alias eql? == # :nodoc:

    def hash # :nodoc:
      to_h.hash
    end
  end
end

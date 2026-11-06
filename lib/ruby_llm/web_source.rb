# frozen_string_literal: true

module RubyLLM
  # A WebSource is a page a hosted web search used to answer. They appear on
  # Message#web_sources, normalized across providers. A Citation is different:
  # it links a span of the answer to what supports it, so a search usually
  # has more sources than citations.
  #
  #   response = chat.with_provider_tools(:web_search).ask "What changed in Ruby 4.0?"
  #   response.web_sources.map(&:url) # => ["https://www.ruby-lang.org/en/news/", ...]
  #
  class WebSource
    include Support::Inspectable

    # The address the provider reports for the page.
    attr_reader :url

    # The title the provider reports for the page, or +nil+.
    attr_reader :title

    def initialize(url:, title: nil) # :nodoc:
      @url = url
      @title = title
    end

    # Returns the source as a Hash with symbol keys, omitting a +nil+ title.
    def to_h
      { url: url, title: title }.compact
    end

    def inspect_attributes # :nodoc:
      { url: url, title: title }
    end
  end
end

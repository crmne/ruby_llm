# frozen_string_literal: true

module RubyLLM
  # Tool results the model can cite. Providers with native citation support
  # receive citable search result blocks; other providers receive plain text.
  #
  #   def execute(query:)
  #     RubyLLM::SearchResults.new(
  #       title: 'Q4 Report',
  #       url: 'https://drive.example.com/q4-report',
  #       text: report_text
  #     )
  #   end
  class SearchResults < Content
    attr_reader :results

    def initialize(*results, **result)
      results << result if result.any?
      @results = results.map { |entry| normalize(entry) }
      raise ArgumentError, 'SearchResults requires at least one result' if @results.empty?

      super(@results.map { |entry| format_result(entry) }.join("\n\n"))
    end

    # Stays structured so providers with citation support can format natively;
    # Content#format would collapse to plain text.
    def format
      self
    end

    private

    def normalize(entry)
      entry = Utils.deep_symbolize_keys(entry.to_h)
      raise ArgumentError, 'Search results require :title and :text' unless entry[:title] && entry[:text]

      entry.slice(:title, :url, :text)
    end

    # Plain text rendering for providers without citation support.
    def format_result(entry)
      attributes = "title='#{entry[:title]}'"
      attributes += " url='#{entry[:url]}'" if entry[:url]
      "<search_result #{attributes}>\n#{entry[:text]}\n</search_result>"
    end
  end
end

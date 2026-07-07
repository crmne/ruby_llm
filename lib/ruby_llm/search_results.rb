# frozen_string_literal: true

module RubyLLM
  # A SearchResults wraps documents a Tool returns so the model can cite
  # them. It serializes to the search-results convention: a tool message
  # whose content is <tt>{"search_results": [...]}</tt> renders as citable
  # blocks on providers with citation support.
  #
  #   def execute(query:)
  #     docs = MyVectorStore.search(query)
  #
  #     RubyLLM::SearchResults.new(
  #       *docs.map { |doc| { title: doc.name, url: doc.link, text: doc.body } }
  #     )
  #   end
  #
  # Cited passages come back on the response as Message#citations.
  class SearchResults
    KEY = 'search_results' # :nodoc:

    # The normalized results, as an array of hashes with +:title+, +:text+,
    # and optional +:url+ keys.
    attr_reader :results

    # Returns a new SearchResults built from one or more result hashes, or
    # from a single result given as keywords.
    #
    #   RubyLLM::SearchResults.new(title: 'Q4 Report', url: report_url, text: report_text)
    #   RubyLLM::SearchResults.new({ title: 'A', text: '...' }, { title: 'B', text: '...' })
    #
    # Each result is reduced to its +:title+, +:url+, and +:text+ entries.
    # Raises ArgumentError if no results are given or a result is missing
    # +:title+ or +:text+.
    def initialize(*results, **result)
      results << result if result.any?
      @results = results.map { |entry| normalize(entry) }
      raise ArgumentError, 'SearchResults requires at least one result' if @results.empty?
    end

    def self.from_content(content) # :nodoc:
      return unless content.is_a?(String) && content.lstrip.start_with?('{')

      parsed = JSON.parse(content)
      entries = parsed[KEY]
      return unless entries.is_a?(Array) && entries.any?

      new(*entries)
    rescue JSON::ParserError, ArgumentError
      nil
    end

    def to_h # :nodoc:
      { KEY => results }
    end

    def to_json(*args) # :nodoc:
      JSON.generate(to_h, *args)
    end

    private

    def normalize(entry)
      entry = Utils.deep_symbolize_keys(entry.to_h)
      raise ArgumentError, 'Search results require :title and :text' unless entry[:title] && entry[:text]

      entry.slice(:title, :url, :text)
    end
  end
end

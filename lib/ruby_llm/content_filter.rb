# frozen_string_literal: true

module RubyLLM
  # A ContentFilter is one verdict of the provider's content filtering on a
  # request or its response, such as Azure's hate or protected material
  # filters. They appear on Message#content_filters for providers that
  # report them, whether or not they stopped the response, so you can see
  # why a reply ended with Message#content_filtered? or what came close.
  #
  #   response = chat.ask "Summarize this paper"
  #   response.content_filtered?                       # => true
  #   response.content_filters.select(&:filtered?).map(&:category) # => ["hate"]
  #
  # A verdict names a category and a severity, never the text it judged.
  class ContentFilter
    include Support::Inspectable

    SOURCES = %i[prompt completion].freeze # :nodoc:

    # Which side was judged: +:prompt+ for the request, +:completion+ for
    # the response.
    attr_reader :source

    # The provider's name for the category, such as <tt>"hate"</tt>,
    # <tt>"jailbreak"</tt>, or <tt>"protected_material_text"</tt>.
    attr_reader :category

    # The severity the provider gave, such as <tt>"safe"</tt>,
    # <tt>"low"</tt>, or <tt>"medium"</tt>, or +nil+ for a category
    # judged only as detected or not.
    attr_reader :severity

    def self.from_h(data) # :nodoc:
      data = data.transform_keys(&:to_sym)
      new(source: data[:source], category: data[:category], severity: data[:severity],
          filtered: data[:filtered], detected: data[:detected])
    end

    def initialize(source:, category:, severity: nil, filtered: false, detected: nil) # :nodoc:
      @source = source&.to_sym
      @category = category.to_s
      @severity = severity
      @filtered = filtered == true
      @detected = detected
    end

    # Returns whether the filter blocked or cut the text it judged.
    def filtered?
      @filtered
    end

    # Returns whether the provider detected what the category looks for,
    # such as a jailbreak attempt or protected material, or +nil+ for a
    # category judged by severity.
    def detected?
      @detected
    end

    # Returns the verdict as a Hash, omitting +nil+ values.
    def to_h
      { source: source, category: category, severity: severity, filtered: filtered?, detected: @detected }.compact
    end

    def inspect_attributes # :nodoc:
      to_h
    end
  end
end

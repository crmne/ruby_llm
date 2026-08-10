# frozen_string_literal: true

module RubyLLM
  # A Tokens holds the token counts a provider reported for a single
  # response. Instances are read from Message#tokens and Chunk#tokens.
  # Counts the provider did not report are +nil+.
  #
  #   response = chat.ask "What is the capital of France?"
  #   response.tokens.input       # standard input tokens
  #   response.tokens.output      # billable output tokens
  #   response.tokens.cache_read  # prompt cache reads
  #   response.tokens.cache_write # prompt cache writes
  #
  class Tokens
    include Inspectable

    # The number of standard (non-cached) input tokens, or +nil+ if the
    # provider did not report it.
    attr_reader :input

    # The number of billable output tokens, or +nil+ if the provider did
    # not report it. Includes thinking tokens when the provider bills
    # them as output.
    attr_reader :output

    # The number of tokens served from the provider's prompt cache, or
    # +nil+ if the provider did not report it.
    attr_reader :cache_read

    # The number of tokens written to the provider's prompt cache, or
    # +nil+ if the provider did not report it.
    attr_reader :cache_write

    # The number of thinking (reasoning) tokens, or +nil+ if the provider
    # does not report them.
    attr_reader :thinking

    # The provider's server-tool usage counters as a Hash, such as
    # <tt>{"web_search_requests" => 2}</tt>, or +nil+ if the provider did
    # not report any. Counters are provider-shaped and billed per use, not
    # in tokens.
    attr_reader :server_tool_use

    def initialize(input: nil, output: nil, cache_read: nil, cache_write: nil, thinking: nil, # :nodoc:
                   server_tool_use: nil)
      @input = input
      @output = output
      @cache_read = cache_read
      @cache_write = cache_write
      @thinking = thinking
      @server_tool_use = server_tool_use
    end

    # Sums token counts across provider attempts. A bucket remains +nil+ when
    # no attempt reported it.
    def self.aggregate(tokens)
      tokens = Array(tokens).compact
      return new if tokens.empty?
      return tokens.first if tokens.one?

      values = %i[input output cache_read cache_write thinking].to_h do |component|
        reported = tokens.filter_map { |usage| usage.public_send(component) }
        [component, reported.empty? ? nil : reported.sum]
      end
      new(**values, server_tool_use: aggregate_server_tool_use(tokens))
    end

    def self.aggregate_server_tool_use(tokens) # :nodoc:
      reported = tokens.filter_map(&:server_tool_use)
      return nil if reported.empty?

      reported.each_with_object({}) do |counters, total|
        counters.each { |tool, count| total[tool] = total.fetch(tool, 0) + count.to_i }
      end
    end
    private_class_method :aggregate_server_tool_use

    # Returns the counts as a hash with keys +:input_tokens+,
    # +:output_tokens+, +:cache_read_tokens+, +:cache_write_tokens+, and
    # +:thinking_tokens+, omitting +nil+ counts.
    #
    #   response.tokens.to_h
    #   # => {input_tokens: 14, output_tokens: 5}
    #
    def to_h
      {
        input_tokens: input,
        output_tokens: output,
        cache_read_tokens: cache_read,
        cache_write_tokens: cache_write,
        thinking_tokens: thinking,
        server_tool_use: server_tool_use
      }.compact
    end

    def inspect_attributes # :nodoc:
      to_h
    end
  end
end

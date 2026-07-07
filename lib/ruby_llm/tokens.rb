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

    def initialize(input: nil, output: nil, cache_read: nil, cache_write: nil, thinking: nil) # :nodoc:
      @input = input
      @output = output
      @cache_read = cache_read
      @cache_write = cache_write
      @thinking = thinking
    end

    def self.build(input: nil, output: nil, cache_read: nil, cache_write: nil, thinking: nil) # :nodoc:
      return nil if [input, output, cache_read, cache_write, thinking].all?(&:nil?)

      new(
        input: input,
        output: output,
        cache_read: cache_read,
        cache_write: cache_write,
        thinking: thinking
      )
    end

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
        thinking_tokens: thinking
      }.compact
    end
  end
end

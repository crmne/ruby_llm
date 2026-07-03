# frozen_string_literal: true

module RubyLLM
  # Represents token usage for a response.
  class Tokens
    attr_reader :input, :output, :cached, :cache_creation, :thinking

    def initialize(input: nil, output: nil, cached: nil, cache_creation: nil, thinking: nil)
      @input = input
      @output = output
      @cached = cached
      @cache_creation = cache_creation
      @thinking = thinking
    end

    def self.build(input: nil, output: nil, cached: nil, cache_creation: nil, thinking: nil)
      return nil if [input, output, cached, cache_creation, thinking].all?(&:nil?)

      new(
        input: input,
        output: output,
        cached: cached,
        cache_creation: cache_creation,
        thinking: thinking
      )
    end

    def to_h
      {
        input_tokens: input,
        output_tokens: output,
        cached_tokens: cached,
        cache_creation_tokens: cache_creation,
        thinking_tokens: thinking
      }.compact
    end

    def cache_read
      cached
    end

    def cache_write
      cache_creation
    end
  end
end

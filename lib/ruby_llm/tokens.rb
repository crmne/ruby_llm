# frozen_string_literal: true

module RubyLLM
  # Represents token usage for a response.
  class Tokens
    attr_reader :input, :output, :cached, :cache_creation, :thinking

    # rubocop:disable Metrics/ParameterLists
    def initialize(input: nil, output: nil, cached: nil, cache_creation: nil, thinking: nil, reasoning: nil)
      @input = input
      @output = output
      @cached = cached
      @cache_creation = cache_creation
      @thinking = thinking || reasoning
    end
    # rubocop:enable Metrics/ParameterLists

    # rubocop:disable Metrics/ParameterLists
    def self.build(input: nil, output: nil, cached: nil, cache_creation: nil, thinking: nil, reasoning: nil)
      return nil if [input, output, cached, cache_creation, thinking, reasoning].all?(&:nil?)

      new(
        input: input,
        output: output,
        cached: cached,
        cache_creation: cache_creation,
        thinking: thinking,
        reasoning: reasoning
      )
    end
    # rubocop:enable Metrics/ParameterLists

    def to_h
      {
        input_tokens: input,
        output_tokens: output,
        cached_tokens: cached,
        cache_creation_tokens: cache_creation,
        thinking_tokens: thinking
      }.compact
    end

    def reasoning
      thinking
    end
  end
end

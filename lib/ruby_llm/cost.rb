# frozen_string_literal: true

module RubyLLM
  # Represents the cost of token usage for a model response.
  class Cost
    COMPONENTS = %i[input output cache_read cache_write].freeze
    PER_MILLION = 1_000_000.0

    attr_reader :tokens, :model

    def self.aggregate(costs)
      costs = costs.compact.select(&:tokens?)
      return new(amounts: {}, has_tokens: false) if costs.empty?

      missing = COMPONENTS.select do |component|
        costs.any? { |cost| cost.missing?(component) }
      end

      amounts = COMPONENTS.to_h do |component|
        [component, missing.include?(component) ? nil : aggregate_component(costs, component)]
      end

      new(amounts:, missing:, has_tokens: true)
    end

    def initialize(tokens: nil, model: nil, amounts: nil, missing: [], has_tokens: nil)
      @tokens = tokens
      @model = normalize_model(model)
      @amounts = amounts
      @missing = missing
      @has_tokens = has_tokens
    end

    def input
      amount_for(:input)
    end

    def output
      amount_for(:output)
    end

    def cache_read
      amount_for(:cache_read)
    end

    def cache_write
      amount_for(:cache_write)
    end

    alias cached_input cache_read
    alias cache_creation cache_write

    def total
      return nil unless tokens?
      return nil if COMPONENTS.any? { |component| missing?(component) }

      costs = COMPONENTS.filter_map { |component| public_send(component) }
      return nil if costs.empty?

      costs.sum
    end

    def to_h
      {
        input: input,
        output: output,
        cache_read: cache_read,
        cache_write: cache_write,
        total: total
      }.compact
    end

    def tokens?
      return @has_tokens unless @has_tokens.nil?

      COMPONENTS.any? { |component| !tokens_for(component).nil? }
    end

    def missing?(component)
      return @missing.include?(component) if aggregate?

      tokens = tokens_for(component)
      tokens.to_i.positive? && price_for(component).nil?
    end

    private_class_method def self.aggregate_component(costs, component)
      values = costs.filter_map { |cost| cost.public_send(component) }
      values.empty? ? nil : values.sum
    end

    private

    def amount_for(component)
      return @amounts[component] if aggregate?

      token_count = tokens_for(component)
      return nil if token_count.nil?

      token_count = token_count.to_i
      return 0.0 if token_count.zero?

      price = price_for(component)
      return nil unless price

      token_count * price / PER_MILLION
    end

    def aggregate?
      !@amounts.nil?
    end

    def tokens_for(component)
      return unless tokens

      case component
      when :input
        tokens.input
      when :output
        tokens.output
      when :cache_read
        tokens.cache_read
      when :cache_write
        tokens.cache_write
      end
    end

    def price_for(component)
      case component
      when :input
        text_pricing.input
      when :output
        text_pricing.output
      when :cache_read
        text_pricing.cache_read_input
      when :cache_write
        text_pricing.cache_write_input
      end
    end

    def text_pricing
      model&.pricing&.text_tokens || RubyLLM::Model::PricingCategory.new
    end

    def normalize_model(model)
      return RubyLLM.models.find(model.to_s) if model.is_a?(String) || model.is_a?(Symbol)
      return model.to_llm if model.respond_to?(:to_llm)
      return model if model.respond_to?(:pricing)

      nil
    rescue ModelNotFoundError
      nil
    end
  end
end

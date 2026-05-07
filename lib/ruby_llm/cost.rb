# frozen_string_literal: true

module RubyLLM
  # Represents the cost of token usage for a model response.
  class Cost
    COMPONENTS = %i[input output cache_read cache_write thinking].freeze
    PER_MILLION = 1_000_000.0

    attr_reader :tokens, :model, :category

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

    # rubocop:disable Metrics/ParameterLists
    def initialize(tokens: nil, model: nil, amounts: nil, missing: [], has_tokens: nil, category: :text_tokens,
                   input_details: nil)
      @tokens = tokens
      @model = normalize_model(model)
      @amounts = amounts
      @missing = missing
      @has_tokens = has_tokens
      @category = category.to_sym
      @input_details = input_details
    end
    # rubocop:enable Metrics/ParameterLists

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

    def thinking
      amount_for(:thinking)
    end

    alias reasoning thinking

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
        thinking: thinking,
        total: total
      }.compact
    end

    def tokens?
      return @has_tokens unless @has_tokens.nil?

      COMPONENTS.any? { |component| !tokens_for(component).nil? }
    end

    def missing?(component)
      return @missing.include?(component) if aggregate?
      return image_input_missing? if component == :input && detailed_image_input?
      return false if component == :thinking && !thinking_priced_separately?

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
      return image_input_amount if component == :input && detailed_image_input?

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
      when :thinking
        tokens.thinking if thinking_priced_separately?
      end
    end

    def price_for(component)
      case component
      when :input
        text_pricing.input
      when :output
        output_pricing.output
      when :cache_read
        text_pricing.cache_read_input
      when :cache_write
        text_pricing.cache_write_input
      when :thinking
        text_pricing.reasoning_output
      end
    end

    def text_pricing
      model&.pricing&.text_tokens || RubyLLM::Model::PricingCategory.new
    end

    def image_pricing
      model&.pricing&.images || RubyLLM::Model::PricingCategory.new
    end

    def output_pricing
      image_cost? && image_pricing.output ? image_pricing : text_pricing
    end

    def image_cost?
      %i[image images].include?(category)
    end

    def detailed_image_input?
      image_cost? && @input_details.is_a?(Hash) && image_input_parts.any? { |_, tokens, _| !tokens.nil? }
    end

    def image_input_amount
      return nil if image_input_missing?

      image_input_parts.filter_map do |_, token_count, price|
        next if token_count.nil? || token_count.to_i.zero?

        token_count.to_i * price / PER_MILLION
      end.sum
    end

    def image_input_missing?
      image_input_parts.any? do |_, token_count, price|
        token_count.to_i.positive? && price.nil?
      end
    end

    def image_input_parts
      [
        [:text, input_detail('text_tokens'), text_pricing.input],
        [:image, input_detail('image_tokens'), image_pricing.input || text_pricing.input]
      ]
    end

    def input_detail(key)
      @input_details[key] || @input_details[key.to_sym]
    end

    def thinking_priced_separately?
      reasoning_price = text_pricing.reasoning_output
      return false unless reasoning_price

      output_price = text_pricing.output
      output_price.nil? || reasoning_price != output_price
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

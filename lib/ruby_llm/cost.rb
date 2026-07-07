# frozen_string_literal: true

module RubyLLM
  # A Cost prices token usage in US dollars using pricing from the model
  # registry. Message#cost returns the cost of a single response, and
  # Model#cost_for prices any token usage against a specific model.
  #
  #   response = chat.ask "Summarize Ruby's object model."
  #   response.cost.total
  #
  #   cost = model.cost_for(response.tokens)
  #   cost.input
  #   cost.output
  #
  # The components are RubyLLM's normalized token buckets: #input, #output,
  # #cache_read, #cache_write, and #thinking. When the registry lacks
  # pricing for tokens that were used, the affected component and #total
  # return +nil+ instead of a false zero.
  class Cost
    COMPONENTS = %i[input output cache_read cache_write thinking].freeze # :nodoc:
    PER_MILLION = 1_000_000.0 # :nodoc:

    attr_reader :tokens, :model, :category # :nodoc:

    # Combines several costs into a Cost::Aggregate that sums each
    # component across messages. Ignores +nil+ entries.
    #
    #   cost = RubyLLM::Cost.aggregate(messages.map(&:cost))
    #   cost.total
    #
    def self.aggregate(costs)
      Aggregate.build(costs)
    end

    # Rebuilds a cost from a stored breakdown Hash, as produced by #to_h and
    # persisted alongside a message. Keys may be Strings or Symbols. Returns a
    # Cost::Aggregate whose component readers return the recorded amounts and
    # whose #total equals the recorded +:total+.
    #
    #   RubyLLM::Cost.from_h(message.cost_details).total
    #
    def self.from_h(hash)
      amounts = COMPONENTS.to_h { |component| [component, hash[component] || hash[component.to_s]] }
      total_recorded = hash.key?(:total) || hash.key?('total')
      missing = total_recorded ? [] : COMPONENTS.reject { |component| amounts[component] }

      Aggregate.new(amounts:, missing:, tokens: amounts.values.any? { |amount| !amount.nil? })
    end

    def initialize(tokens: nil, model: nil, category: :text_tokens, input_details: nil) # :nodoc:
      @tokens = tokens
      @model = normalize_model(model)
      @category = category.to_sym
      @input_details = input_details
    end

    # Returns the cost of input tokens in US dollars, or +nil+ when the
    # token count or its pricing is unavailable.
    def input
      amount_for(:input)
    end

    # Returns the cost of billable output tokens in US dollars, or +nil+
    # when the token count or its pricing is unavailable.
    def output
      amount_for(:output)
    end

    # Returns the cost of cache-read input tokens in US dollars, or +nil+
    # when the token count or its pricing is unavailable.
    def cache_read
      amount_for(:cache_read)
    end

    # Returns the cost of cache-write input tokens in US dollars, or +nil+
    # when the token count or its pricing is unavailable.
    def cache_write
      amount_for(:cache_write)
    end

    # Returns the cost of thinking tokens in US dollars, or +nil+ when
    # the model does not price reasoning output separately from regular
    # output or the token count is unavailable. When not priced
    # separately, thinking tokens are part of #output.
    def thinking
      amount_for(:thinking)
    end

    # Returns the sum of all components in US dollars. Returns +nil+ when
    # there is no token usage, or when pricing is missing for tokens that
    # were used.
    def total
      return nil unless tokens?
      return nil if COMPONENTS.any? { |component| missing?(component) }

      costs = COMPONENTS.filter_map { |component| public_send(component) }
      return nil if costs.empty?

      costs.sum
    end

    # Returns a hash of component costs in US dollars, plus +:total+,
    # omitting +nil+ values.
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

    def tokens? # :nodoc:
      COMPONENTS.any? { |component| !tokens_for(component).nil? }
    end

    def missing?(component) # :nodoc:
      return image_input_missing? if component == :input && detailed_image_input?
      return false if component == :thinking && !thinking_priced_separately?

      tokens = tokens_for(component)
      tokens.to_i.positive? && price_for(component).nil?
    end

    # An Aggregate is the combined cost of several messages, summing each
    # component across them. Chat#cost and Cost.aggregate return Aggregate
    # objects, which respond to the same component readers as Cost.
    #
    #   chat.cost.total
    #
    # A component returns +nil+ when pricing was missing for one of the
    # messages, or when no message has a cost for that component.
    class Aggregate
      def self.build(costs) # :nodoc:
        costs = costs.compact.select(&:tokens?)

        missing = COMPONENTS.select do |component|
          costs.any? { |cost| cost.missing?(component) }
        end

        amounts = COMPONENTS.to_h do |component|
          values = costs.filter_map { |cost| cost.public_send(component) }
          [component, missing.include?(component) || values.empty? ? nil : values.sum]
        end

        new(amounts:, missing:, tokens: costs.any?)
      end

      def initialize(amounts:, missing:, tokens:) # :nodoc:
        @amounts = amounts
        @missing = missing
        @tokens = tokens
      end

      ##
      # :method: input
      # Returns the summed cost of input tokens in US dollars, or +nil+
      # when pricing was missing for a message or no message reports
      # input tokens.

      ##
      # :method: output
      # Returns the summed cost of billable output tokens in US dollars,
      # or +nil+ when pricing was missing for a message or no message
      # reports output tokens.

      ##
      # :method: cache_read
      # Returns the summed cost of cache-read input tokens in US dollars,
      # or +nil+ when pricing was missing for a message or no message
      # reports cache-read tokens.

      ##
      # :method: cache_write
      # Returns the summed cost of cache-write input tokens in US dollars,
      # or +nil+ when pricing was missing for a message or no message
      # reports cache-write tokens.

      ##
      # :method: thinking
      # Returns the summed cost of separately priced thinking tokens in US
      # dollars, or +nil+ when no message has a thinking cost.

      COMPONENTS.each do |component|
        define_method(component) { @amounts[component] }
      end

      # Returns the sum of all components in US dollars. Returns +nil+
      # when there is no token usage, or when pricing was missing for any
      # component.
      def total
        return nil unless tokens?
        return nil if @missing.any?

        costs = COMPONENTS.filter_map { |component| public_send(component) }
        return nil if costs.empty?

        costs.sum
      end

      # Returns a hash of component costs in US dollars, plus +:total+,
      # omitting +nil+ values.
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

      def tokens? # :nodoc:
        @tokens
      end

      def missing?(component) # :nodoc:
        @missing.include?(component)
      end
    end

    private

    def amount_for(component)
      return image_input_amount if component == :input && detailed_image_input?

      token_count = tokens_for(component)
      return nil if token_count.nil?

      token_count = token_count.to_i
      return 0.0 if token_count.zero?

      price = price_for(component)
      return nil unless price

      token_count * price / PER_MILLION
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

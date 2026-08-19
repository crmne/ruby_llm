# frozen_string_literal: true

module RubyLLM
  # A Cost prices token usage in US dollars using pricing from the model
  # registry. Usage entries own accounting events; Message and Chat aggregate
  # calls, and Model#cost_for prices any token usage against a specific model.
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
  #
  # When the provider reports the exact cost of a call (OpenRouter does on
  # every response), #total returns the reported amount instead of a
  # registry-price estimate, even when registry pricing is missing.
  #
  # Costs are computed when the object is built and frozen from then on.
  # ::aggregate and ::from_h return the same class, so a single call, a
  # whole chat, and a stored breakdown all read the same way.
  class Cost
    include Inspectable

    COMPONENTS = %i[input output cache_read cache_write thinking].freeze # :nodoc:
    PER_MILLION = 1_000_000.0 # :nodoc:

    class << self
      # Combines several costs into one Cost that sums each component.
      # Ignores +nil+ entries. A component returns +nil+ when pricing was
      # missing for one of the calls, or when no call has a cost for that
      # component.
      #
      #   cost = RubyLLM::Cost.aggregate(messages.map(&:cost))
      #   cost.total
      #
      def aggregate(costs, complete: true)
        costs = costs.compact.select(&:tokens?)

        missing = COMPONENTS.select do |component|
          costs.any? { |cost| cost.missing?(component) }
        end

        amounts = COMPONENTS.to_h do |component|
          values = costs.filter_map { |cost| cost.public_send(component) }
          [component, missing.include?(component) || values.empty? ? nil : values.sum]
        end

        new(amounts:, missing:, reported: costs.any?, complete:, total: aggregate_total(costs))
      end

      # Rebuilds a cost from a stored breakdown Hash, as produced by #to_h
      # and persisted alongside a usage entry. Keys may be Strings or
      # Symbols. The component readers return the recorded amounts and
      # #total equals the recorded +:total+.
      #
      #   RubyLLM::Cost.from_h({ input: 0.0001, total: 0.0003 }).total
      #
      def from_h(hash, tokens: nil)
        amounts = COMPONENTS.to_h { |component| [component, hash[component] || hash[component.to_s]] }
        total_recorded = hash.key?(:total) || hash.key?('total')
        total = hash[:total] || hash['total'] if total_recorded
        missing = missing_recorded_components(amounts, tokens, total_recorded)

        new(amounts:, missing:, reported: recorded_tokens?(amounts, tokens, total_recorded), total:)
      end

      private

      def aggregate_total(costs)
        totals = costs.map(&:total)
        totals.sum if totals.any? && totals.none?(&:nil?)
      end

      def missing_recorded_components(amounts, tokens, total_recorded)
        return [] if total_recorded
        return COMPONENTS.reject { |component| amounts[component] } unless tokens

        COMPONENTS.select do |component|
          tokens.public_send(component).to_i.positive? && amounts[component].nil?
        end
      end

      def recorded_tokens?(amounts, tokens, total_recorded)
        return COMPONENTS.any? { |component| !tokens.public_send(component).nil? } if tokens

        amounts.values.any? { |amount| !amount.nil? } || total_recorded
      end
    end

    def initialize(tokens: nil, model: nil, category: :text_tokens, input_details: nil, # :nodoc:
                   amounts: nil, missing: nil, reported: nil, complete: true, total: nil)
      if amounts
        @amounts = amounts
        @missing = missing || []
        @reported = reported
      else
        price_tokens(tokens, model, category, input_details)
        total = reported_total if total.nil?
        @reported ||= !total.nil?
      end
      @complete = complete
      @total = total
    end

    # Returns the cost of input tokens in US dollars, or +nil+ when the
    # token count or its pricing is unavailable.
    def input
      @amounts[:input]
    end

    # Returns the cost of billable output tokens in US dollars, or +nil+
    # when the token count or its pricing is unavailable.
    def output
      @amounts[:output]
    end

    # Returns the cost of cache-read input tokens in US dollars, or +nil+
    # when the token count or its pricing is unavailable.
    def cache_read
      @amounts[:cache_read]
    end

    # Returns the cost of cache-write input tokens in US dollars, or +nil+
    # when the token count or its pricing is unavailable.
    def cache_write
      @amounts[:cache_write]
    end

    # Returns the cost of thinking tokens in US dollars, or +nil+ when
    # the model does not price reasoning output separately from regular
    # output or the token count is unavailable. When not priced
    # separately, thinking tokens are part of #output.
    def thinking
      @amounts[:thinking]
    end

    # Returns the sum of all components in US dollars, or the exact amount
    # the provider reported when it reported one. Returns +nil+ when there
    # is no token usage, or when pricing is missing for tokens that were
    # used and the provider reported no cost.
    def total
      return nil unless @complete
      return nil unless tokens?
      return @total unless @total.nil?
      return nil if @missing.any?

      amounts = @amounts.values.compact
      return nil if amounts.empty?

      amounts.sum
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
      @reported
    end

    def missing?(component) # :nodoc:
      @missing.include?(component)
    end

    private

    def price_tokens(tokens, model, category, input_details)
      @tokens = tokens
      @model = normalize_model(model)
      @category = category.to_sym
      @input_details = input_details
      @amounts = COMPONENTS.to_h { |component| [component, amount_for(component)] }
      @missing = COMPONENTS.select { |component| missing_component?(component) }
      @reported = COMPONENTS.any? { |component| !tokens_for(component).nil? }
    end

    def reported_total
      @tokens.reported_cost if @tokens.respond_to?(:reported_cost)
    end

    def missing_component?(component)
      return image_input_missing? if component == :input && detailed_image_input?
      return false if component == :thinking && !thinking_priced_separately?

      tokens_for(component).to_i.positive? && price_for(component).nil?
    end

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
      return unless @tokens

      case component
      when :input
        @tokens.input
      when :output
        @tokens.output
      when :cache_read
        @tokens.cache_read
      when :cache_write
        @tokens.cache_write
      when :thinking
        @tokens.thinking if thinking_priced_separately?
      end
    end

    def price_for(component)
      case component
      when :input then input_price
      when :output then output_price
      when :cache_read then text_price(:cache_read_input_per_million, text_pricing.cache_read_input)
      when :cache_write then text_price(:cache_write_input_per_million, text_pricing.cache_write_input)
      when :thinking then text_price(:reasoning_output_per_million, text_pricing.reasoning_output)
      end
    end

    def input_price
      return text_input_price if @category == :text_tokens || image_cost?

      category_pricing.input || text_input_price
    end

    def output_price
      return image_pricing.output || text_output_price if image_cost?
      return text_output_price if @category == :text_tokens

      category_pricing.output || text_output_price
    end

    def text_input_price
      text_price(:input_per_million, text_pricing.input)
    end

    def text_output_price
      text_price(:output_per_million, text_pricing.output)
    end

    def text_price(attribute, standard_price)
      applicable_text_tier&.public_send(attribute) || standard_price
    end

    def applicable_text_tier
      text_pricing.tier_for(prompt_tokens)
    end

    def prompt_tokens
      tokens_for(:input).to_i + tokens_for(:cache_read).to_i + tokens_for(:cache_write).to_i
    end

    def text_pricing
      @model&.pricing&.text_tokens || RubyLLM::Model::PricingCategory.new
    end

    def image_pricing
      @model&.pricing&.images || RubyLLM::Model::PricingCategory.new
    end

    def category_pricing
      return text_pricing if @category == :text_tokens
      return image_pricing if image_cost?

      pricing = @model&.pricing
      return RubyLLM::Model::PricingCategory.new unless pricing.respond_to?(@category)

      pricing.public_send(@category)
    end

    def image_cost?
      %i[image images].include?(@category)
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
      text_input_price = applicable_text_tier&.input_per_million || text_pricing.input
      [
        [:text, input_detail('text_tokens'), text_input_price],
        [:image, input_detail('image_tokens'), image_pricing.input || text_input_price]
      ]
    end

    def input_detail(key)
      @input_details[key] || @input_details[key.to_sym]
    end

    def thinking_priced_separately?
      tier = applicable_text_tier
      reasoning_price = tier&.reasoning_output_per_million || text_pricing.reasoning_output
      return false unless reasoning_price

      output_price = tier&.output_per_million || text_pricing.output
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

    def inspect_attributes # :nodoc:
      to_h
    end
  end
end

# frozen_string_literal: true

module RubyLLM
  class Model
    # A PricingCategory holds the standard, batch, and long-context pricing
    # tiers for one kind of model usage, such as text tokens or images.
    # Model#pricing returns a Pricing collection whose categories are
    # PricingCategory instances. Prices are in USD per million tokens.
    #
    #   model    = RubyLLM.models.find "claude-sonnet-5"
    #   category = model.pricing.text_tokens
    #   category.input  # => 3
    #   category.output # => 15
    #
    class PricingCategory
      # The billing tiers a category may define.
      TIERS = %i[standard batch long_context].freeze

      # The standard-tier PricingTier, or +nil+ when the model has no
      # standard pricing for this category.
      attr_reader :standard

      # The batch-tier PricingTier, or +nil+ when the model has no batch
      # pricing for this category.
      attr_reader :batch

      # The long-context PricingTier, or +nil+ when the model has no
      # separate rates for prompts above #long_context_threshold.
      attr_reader :long_context

      # Prompt-size threshold (in tokens) above which long-context rates
      # apply, or +nil+ when the model has no long-context tier.
      attr_reader :long_context_threshold

      def initialize(data = {}) # :nodoc:
        data = data.transform_keys(&:to_sym) if data.respond_to?(:transform_keys)

        @standard = tier_from(data[:standard])
        @batch = tier_from(data[:batch])
        @long_context = tier_from(data[:long_context])
        @long_context_threshold = Integer(data[:long_context_threshold], exception: false)
      end

      # Returns the standard-tier input price in USD per million tokens,
      # or +nil+ if the price is missing.
      def input
        standard&.input_per_million
      end

      # Returns the standard-tier output price in USD per million tokens,
      # or +nil+ if the price is missing.
      def output
        standard&.output_per_million
      end

      # Returns the standard-tier cache read price in USD per million
      # tokens, or +nil+ if the price is missing.
      def cache_read_input
        standard&.cache_read_input_per_million
      end

      # Returns the standard-tier cache write price in USD per million
      # tokens, or +nil+ if the price is missing.
      def cache_write_input
        standard&.cache_write_input_per_million
      end

      # Returns the standard-tier reasoning output price in USD per million
      # tokens, or +nil+ if the price is missing.
      def reasoning_output
        standard&.reasoning_output_per_million
      end

      # Returns the PricingTier that applies for a prompt of the given size.
      # Uses #long_context when that tier exists and +prompt_tokens+ is
      # greater than #long_context_threshold; otherwise returns #standard.
      def tier_for(prompt_tokens)
        if long_context && long_context_threshold &&
           prompt_tokens.to_i > long_context_threshold
          long_context
        else
          standard
        end
      end

      # Returns a Hash with present tier hashes and optional
      # +:long_context_threshold+, omitting absent entries.
      def to_h
        result = {}
        result[:standard] = standard.to_h if standard
        result[:batch] = batch.to_h if batch
        result[:long_context] = long_context.to_h if long_context
        result[:long_context_threshold] = long_context_threshold if long_context_threshold
        result
      end

      # Builds long-context rates and threshold from a models.dev-style cost
      # Hash (as stored on Model#metadata under +:cost+). Returns
      # <tt>[rates_hash, threshold]</tt>, or <tt>[nil, nil]</tt> when the
      # cost has no context tier.
      def self.long_context_from_cost(cost) # :nodoc:
        cost = RubyLLM::Utils.deep_symbolize_keys(cost || {})
        return [nil, nil] if cost.empty?

        entry, threshold = context_cost(cost)
        return [nil, nil] unless entry

        rates = {
          input_per_million: entry[:input],
          output_per_million: entry[:output],
          cache_read_input_per_million: entry[:cache_read],
          cache_write_input_per_million: entry[:cache_write],
          reasoning_output_per_million: entry[:reasoning]
        }.compact
        rates.empty? ? [nil, nil] : [rates, threshold]
      end

      def self.context_cost(cost) # :nodoc:
        context_tier = Array(cost[:tiers]).find do |entry|
          entry.is_a?(Hash) && entry.dig(:tier, :type).to_s == 'context'
        end
        if context_tier
          [context_tier, Integer(context_tier.dig(:tier, :size), exception: false)]
        elsif cost[:context_over_200k].is_a?(Hash)
          [cost[:context_over_200k], 200_000]
        end
      end

      private_class_method :context_cost

      private

      def tier_from(tier_data)
        return nil if empty_tier?(tier_data)

        PricingTier.new(tier_data || {})
      end

      def empty_tier?(tier_data)
        return true unless tier_data

        tier_data.values.all?(&:nil?)
      end
    end
  end
end

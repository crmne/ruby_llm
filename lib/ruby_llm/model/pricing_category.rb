# frozen_string_literal: true

module RubyLLM
  class Model
    # A PricingCategory holds the standard and batch pricing tiers for one
    # kind of model usage, such as text tokens or images. Model#pricing
    # returns a Pricing collection whose categories are PricingCategory
    # instances. Prices are in USD per million tokens.
    #
    #   model    = RubyLLM.models.find "claude-sonnet-4-6"
    #   category = model.pricing.text_tokens
    #   category.input  # => 3
    #   category.output # => 15
    #
    class PricingCategory
      # The standard-tier PricingTier, or +nil+ when the model has no
      # standard pricing for this category.
      attr_reader :standard

      # The batch-tier PricingTier, or +nil+ when the model has no batch
      # pricing for this category.
      attr_reader :batch

      def initialize(data = {}) # :nodoc:
        @standard = PricingTier.new(data[:standard] || {}) unless empty_tier?(data[:standard])
        @batch = PricingTier.new(data[:batch] || {}) unless empty_tier?(data[:batch])
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

      # Returns a Hash with +:standard+ and +:batch+ tier hashes, omitting
      # absent tiers.
      def to_h
        result = {}
        result[:standard] = standard.to_h if standard
        result[:batch] = batch.to_h if batch
        result
      end

      private

      def empty_tier?(tier_data)
        return true unless tier_data

        tier_data.values.all?(&:nil?)
      end
    end
  end
end

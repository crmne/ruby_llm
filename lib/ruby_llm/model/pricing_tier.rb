# frozen_string_literal: true

module RubyLLM
  class Model
    # A PricingTier holds the prices a model charges within one billing tier,
    # standard or batch. Each price is in USD per one million tokens. Prices
    # missing from the registry read as +nil+. A zero price means the usage
    # is free.
    #
    # Instances come from PricingCategory#standard and PricingCategory#batch:
    #
    #   model = RubyLLM.models.find "claude-sonnet-4-6"
    #   tier  = model.pricing.text_tokens.standard
    #   tier.input_per_million  # => 3
    #   tier.output_per_million # => 15
    #
    class PricingTier
      # The names of the price readers a tier responds to.
      ATTRIBUTES = %i[
        input_per_million
        output_per_million
        cache_read_input_per_million
        cache_write_input_per_million
        reasoning_output_per_million
      ].freeze

      def initialize(data = {}) # :nodoc:
        @values = {}

        data.each do |key, value|
          next if value.nil?

          @values[key.to_sym] = value
        end
      end

      ##
      # :method: input_per_million
      #
      # Returns the USD price per million input tokens, or +nil+ if the
      # price is missing.

      ##
      # :method: output_per_million
      #
      # Returns the USD price per million output tokens, or +nil+ if the
      # price is missing.

      ##
      # :method: cache_read_input_per_million
      #
      # Returns the USD price per million input tokens read from the
      # provider's prompt cache, or +nil+ if the price is missing.

      ##
      # :method: cache_write_input_per_million
      #
      # Returns the USD price per million input tokens written to the
      # provider's prompt cache, or +nil+ if the price is missing.

      ##
      # :method: reasoning_output_per_million
      #
      # Returns the USD price per million reasoning output tokens, or +nil+
      # if the price is missing.

      ATTRIBUTES.each do |attribute|
        define_method(attribute) do
          @values[attribute]
        end
      end

      # Returns a new Hash of the tier's prices with Symbol keys. Missing
      # prices are omitted.
      #
      #   tier.to_h
      #   # => {input_per_million: 3, output_per_million: 15, ...}
      #
      def to_h
        @values.dup
      end
    end
  end
end

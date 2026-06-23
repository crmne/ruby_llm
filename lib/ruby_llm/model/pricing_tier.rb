# frozen_string_literal: true

module RubyLLM
  module Model
    # Stores non-zero pricing values for a single pricing tier.
    class PricingTier
      ATTRIBUTES = %i[
        input_per_million
        output_per_million
        cache_read_input_per_million
        cache_write_input_per_million
        reasoning_output_per_million
      ].freeze

      def initialize(data = {})
        @values = {}

        data.each do |key, value|
          next unless value && value != 0.0

          @values[key.to_sym] = value
        end
      end

      ATTRIBUTES.each do |attribute|
        define_method(attribute) do
          @values[attribute]
        end
      end

      def to_h
        @values
      end
    end
  end
end

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
        cached_input_per_million
        cache_creation_input_per_million
        reasoning_output_per_million
      ].freeze

      def initialize(data = {})
        @values = {}

        data.each do |key, value|
          @values[key.to_sym] = value if value && value != 0.0
        end
      end

      ATTRIBUTES.each do |attribute|
        define_method(attribute) do
          @values[attribute]
        end

        define_method("#{attribute}=") do |value|
          @values[attribute] = value if value && value != 0.0
        end
      end

      def [](key)
        @values[key.to_sym]
      end

      def to_h
        @values
      end
    end
  end
end

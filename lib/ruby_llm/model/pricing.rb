# frozen_string_literal: true

module RubyLLM
  module Model
    # A collection that manages and provides access to different categories of pricing information
    class Pricing
      CATEGORIES = %i[text_tokens images audio_tokens embeddings].freeze

      def initialize(data)
        @data = {}

        CATEGORIES.each do |category|
          @data[category] = PricingCategory.new(data[category]) if data[category] && !empty_pricing?(data[category])
        end
      end

      def text_tokens
        category(:text_tokens)
      end

      def images
        category(:images)
      end

      def audio_tokens
        category(:audio_tokens)
      end

      def embeddings
        category(:embeddings)
      end

      def to_h
        @data.transform_values(&:to_h)
      end

      private

      def category(name)
        @data[name] || PricingCategory.new
      end

      def empty_pricing?(data)
        return true unless data

        %i[standard batch].each do |tier|
          next unless data[tier]

          data[tier].each_value do |value|
            return false if value && value != 0.0
          end
        end

        true
      end
    end
  end
end

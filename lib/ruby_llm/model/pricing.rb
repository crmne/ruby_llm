# frozen_string_literal: true

module RubyLLM
  class Model
    # A Pricing groups a model's prices by usage category: text tokens,
    # images, audio tokens, and embeddings. Each category is a
    # PricingCategory. Prices are in USD per million tokens. Instances come
    # from Model#pricing.
    #
    #   model = RubyLLM.models.find "claude-sonnet-4-6"
    #   model.pricing.text_tokens.input   # => 3
    #   model.pricing.text_tokens.output  # => 15
    #
    class Pricing
      # The pricing categories a model may define.
      CATEGORIES = %i[text_tokens images audio_tokens embeddings].freeze

      def initialize(data) # :nodoc:
        @data = {}

        CATEGORIES.each do |category|
          @data[category] = PricingCategory.new(data[category]) if data[category] && !empty_pricing?(data[category])
        end
      end

      # Returns the PricingCategory for text token prices, or an empty
      # category if the model has none.
      def text_tokens
        category(:text_tokens)
      end

      # Returns the PricingCategory for image generation prices, or an empty
      # category if the model has none.
      def images
        category(:images)
      end

      # Returns the PricingCategory for audio token prices, or an empty
      # category if the model has none.
      def audio_tokens
        category(:audio_tokens)
      end

      # Returns the PricingCategory for embedding prices, or an empty
      # category if the model has none.
      def embeddings
        category(:embeddings)
      end

      # Returns the pricing data as a nested Hash keyed by category.
      # Categories without prices are omitted.
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
            return false unless value.nil?
          end
        end

        true
      end
    end
  end
end

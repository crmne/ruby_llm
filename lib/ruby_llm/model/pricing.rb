# frozen_string_literal: true

module RubyLLM
  class Model
    # A Pricing groups a model's prices by usage category: text tokens,
    # images, audio tokens, and embeddings, plus the characters, audio
    # seconds, and search units some operations bill instead of tokens.
    # Each category is a PricingCategory. Prices are in USD per million
    # units of the category. Instances come from Model#pricing.
    #
    #   model = RubyLLM.models.find "claude-sonnet-5"
    #   model.pricing.text_tokens.input   # => 3
    #   model.pricing.text_tokens.output  # => 15
    #
    class Pricing
      # The pricing categories a model may define.
      CATEGORIES = %i[text_tokens images audio_tokens embeddings characters audio_seconds search_units].freeze

      # The prices Configuration#price sets, each as the category and the
      # standard-tier price it replaces.
      OVERRIDES = {
        input: %i[text_tokens input_per_million],
        output: %i[text_tokens output_per_million],
        cache_read: %i[text_tokens cache_read_input_per_million],
        cache_write: %i[text_tokens cache_write_input_per_million],
        characters: %i[characters input_per_million],
        audio_seconds: %i[audio_seconds input_per_million],
        search_units: %i[search_units input_per_million]
      }.freeze
      private_constant :OVERRIDES

      class << self
        # Returns +prices+ checked against the prices a configuration can
        # set.
        def override(prices) # :nodoc:
          unknown = prices.keys - OVERRIDES.keys
          if unknown.any? || prices.empty?
            raise ArgumentError, "#{unknown.any? ? "Unknown price: #{unknown.join(', ')}" : 'No price given'}. " \
                                 "Valid prices: #{OVERRIDES.keys.join(', ')}"
          end

          prices.each do |kind, price|
            raise ArgumentError, "The #{kind} price must be a number, got #{price.inspect}" unless price.is_a?(Numeric)
          end
          prices
        end

        # Returns pricing +data+ with the standard-tier +prices+ replaced.
        # A thinking price that equals the output price is the same price,
        # so it follows a new output price, and audio input and output
        # follow the token prices.
        def overridden(data, prices) # :nodoc:
          data = RubyLLM::Support::Utils.deep_dup(data)
          standard = data.dig(:text_tokens, :standard) || {}
          thinking = standard[:reasoning_output_per_million]
          follows = prices.key?(:output) && thinking && thinking == standard[:output_per_million]
          prices.each { |kind, price| override_price(data, *OVERRIDES.fetch(kind), price) }
          data[:text_tokens][:standard][:reasoning_output_per_million] = prices[:output] if follows
          data
        end

        private

        def override_price(data, category, attribute, price)
          ((data[category] ||= {})[:standard] ||= {})[attribute] = price
          audio = data.dig(:audio_tokens, :standard) if category == :text_tokens
          audio[attribute] = price if audio&.key?(attribute)
        end
      end

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

      # Returns the PricingCategory for prices per million input
      # characters, such as a text-to-speech model's, or an empty category
      # if the model has none.
      def characters
        category(:characters)
      end

      # Returns the PricingCategory for prices per million seconds of
      # input audio, such as a transcription model's, or an empty category
      # if the model has none.
      def audio_seconds
        category(:audio_seconds)
      end

      # Returns the PricingCategory for prices per million search units,
      # such as a rerank model's, or an empty category if the model has
      # none.
      def search_units
        category(:search_units)
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

        PricingCategory::TIERS.each do |tier|
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

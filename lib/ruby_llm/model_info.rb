# frozen_string_literal: true

module RubyLLM
  # Information about an AI model's capabilities, pricing, and metadata.
  # Used by the Models registry to help developers choose the right model
  # for their needs.
  #
  # Example:
  #   model = RubyLLM.models.find('gpt-4')
  #   model.supports_vision?          # => true
  #   model.supports_functions?       # => true
  #   model.input_price_per_million   # => 30.0
  class ModelInfo
    attr_reader :id, :name, :provider, :family, :created_at, :context_window, :max_output_tokens, :knowledge_cutoff,
                :modalities, :capabilities, :pricing, :metadata

    def initialize(data)
      @id = data[:id]
      @name = data[:name]
      @provider = data[:provider]
      @family = data[:family]
      @created_at = data[:created_at]
      @context_window = data[:context_window]
      @max_output_tokens = data[:max_output_tokens]
      @knowledge_cutoff = data[:knowledge_cutoff]
      @modalities = Modalities.new(data[:modalities] || {})
      @capabilities = data[:capabilities] || []
      @pricing = PricingCollection.new(data[:pricing] || {})
      @metadata = data[:metadata] || {}
    end

    # Capability methods
    def supports?(capability)
      capabilities.include?(capability.to_s)
    end

    %w[function_calling structured_output batch reasoning citations streaming].each do |cap|
      define_method "#{cap}?" do
        supports?(cap)
      end
    end

    # Backward compatibility methods
    def display_name
      name
    end

    def max_tokens
      max_output_tokens
    end

    def supports_vision?
      modalities.input.include?('image')
    end

    def supports_functions?
      function_calling?
    end

    def input_price_per_million
      pricing.text_tokens.input
    end

    def output_price_per_million
      pricing.text_tokens.output
    end

    def type # rubocop:disable Metrics/PerceivedComplexity
      if modalities.output.include?('embeddings') && !modalities.output.include?('text')
        'embedding'
      elsif modalities.output.include?('image') && !modalities.output.include?('text')
        'image'
      elsif modalities.output.include?('audio') && !modalities.output.include?('text')
        'audio'
      elsif modalities.output.include?('moderation')
        'moderation'
      else
        'chat'
      end
    end

    def to_h
      {
        id: id,
        name: name,
        provider: provider,
        family: family,
        created_at: created_at,
        context_window: context_window,
        max_output_tokens: max_output_tokens,
        knowledge_cutoff: knowledge_cutoff,
        modalities: modalities.to_h,
        capabilities: capabilities,
        pricing: pricing.to_h,
        metadata: metadata
      }
    end
  end

  # Holds and manages input and output modalities for a language model
  class Modalities
    attr_reader :input, :output

    def initialize(data)
      @input = Array(data[:input]).map(&:to_s)
      @output = Array(data[:output]).map(&:to_s)
    end

    def to_h
      {
        input: input,
        output: output
      }
    end
  end

  # A collection that manages and provides access to different categories of pricing information
  # (text tokens, images, audio tokens, embeddings)
  class PricingCollection
    def initialize(data)
      @data = {}

      # Initialize pricing categories
      %i[text_tokens images audio_tokens embeddings].each do |category|
        @data[category] = PricingCategory.new(data[category]) if data[category] && !empty_pricing?(data[category])
      end
    end

    def method_missing(method, *args)
      if respond_to_missing?(method)
        @data[method.to_sym] || PricingCategory.new
      else
        super
      end
    end

    def respond_to_missing?(method, include_private = false)
      %i[text_tokens images audio_tokens embeddings].include?(method.to_sym) || super
    end

    def to_h
      @data.transform_values(&:to_h)
    end

    private

    def empty_pricing?(data)
      # Check if all pricing values in this category are zero or nil
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

  # Represents pricing tiers for different usage categories (standard and batch), managing access to their respective
  # rates
  class PricingCategory
    attr_reader :standard, :batch

    def initialize(data = {})
      @standard = PricingTier.new(data[:standard] || {}) unless empty_tier?(data[:standard])
      @batch = PricingTier.new(data[:batch] || {}) unless empty_tier?(data[:batch])
    end

    # Shorthand methods that default to standard tier
    def input
      standard&.input_per_million
    end

    def output
      standard&.output_per_million
    end

    def cached_input
      standard&.cached_input_per_million
    end

    # Get value for a specific tier
    def [](key)
      key == :batch ? batch : standard
    end

    def to_h
      result = {}
      result[:standard] = standard.to_h if standard
      result[:batch] = batch.to_h if batch
      result
    end

    private

    def empty_tier?(tier_data)
      return true unless tier_data

      tier_data.values.all? { |v| v.nil? || v == 0.0 }
    end
  end

  # A dynamic class for storing non-zero pricing values with flexible attribute access
  class PricingTier
    def initialize(data = {})
      @values = {}

      # Only store non-zero values
      data.each do |key, value|
        @values[key.to_sym] = value if value && value != 0.0
      end
    end

    def method_missing(method, *args)
      if method.to_s.end_with?('=')
        key = method.to_s.chomp('=').to_sym
        @values[key] = args.first if args.first && args.first != 0.0
      elsif @values.key?(method)
        @values[method]
      else
        super
      end
    end

    def respond_to_missing?(method, include_private = false)
      method.to_s.end_with?('=') || @values.key?(method.to_sym) || super
    end

    def to_h
      @values
    end
  end
end

# frozen_string_literal: true

module RubyLLM
  module Model
    # Information about an AI model's capabilities, pricing, and metadata.
    # Used by the Models registry to help developers choose the right model
    # for their needs.
    #
    # Example:
    #   model = RubyLLM.models.find('gpt-4')
    #   model.supports_vision?          # => true
    #   model.supports_functions?       # => true
    #   model.input_price_per_million   # => 30.0
    class Info
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
        @pricing = Pricing.new(data[:pricing] || {})
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
  end
end

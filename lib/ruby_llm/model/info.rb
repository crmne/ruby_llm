# frozen_string_literal: true

module RubyLLM
  module Model
    # Information about an AI model's capabilities, pricing, and metadata.
    class Info
      attr_reader :id, :name, :provider, :family, :created_at, :context_window, :max_output_tokens, :knowledge_cutoff,
                  :modalities, :capabilities, :pricing, :metadata, :reasoning_options

      # Create a default model with assumed capabilities
      def self.default(model_id, provider)
        new(
          id: model_id,
          name: model_id.tr('-', ' ').capitalize,
          provider: provider,
          capabilities: %w[function_calling streaming vision structured_output],
          modalities: { input: %w[text image], output: %w[text] },
          metadata: { warning: 'Assuming model exists, capabilities may not be accurate' }
        )
      end

      def initialize(data)
        @id = data[:id]
        @name = data[:name]
        @provider = data[:provider]
        @family = data[:family]
        @created_at = Utils.to_time(data[:created_at])&.utc
        @context_window = data[:context_window]
        @max_output_tokens = data[:max_output_tokens]
        @knowledge_cutoff = Utils.to_date(data[:knowledge_cutoff])
        @modalities = Modalities.new(data[:modalities] || {})
        @capabilities = data[:capabilities] || []
        @pricing = Pricing.new(data[:pricing] || {})
        @metadata = data[:metadata]&.dup || {}
        @reasoning_options = normalize_reasoning_options(reasoning_options_from(data))
        store_reasoning_options_metadata
      end

      def supports?(capability)
        capabilities.include?(capability.to_s)
      end

      %w[function_calling structured_output batch reasoning citations streaming].each do |cap|
        define_method "#{cap}?" do
          supports?(cap)
        end
      end

      def display_name
        name
      end

      def label
        provider_name = provider_class&.name || provider
        "#{provider_name} - #{display_name}"
      end

      def max_tokens
        max_output_tokens
      end

      def supports_vision?
        modalities.input.include?('image')
      end

      def reasoning_option(type)
        reasoning_options.find { |option| option[:type] == type.to_s }
      end

      def reasoning_option_values(type)
        Array(reasoning_option(type)&.fetch(:values, nil))
      end

      def supports_video?
        modalities.input.include?('video')
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

      def cache_read_input_price_per_million
        pricing.text_tokens.cache_read_input
      end

      def cache_write_input_price_per_million
        pricing.text_tokens.cache_write_input
      end

      alias cached_input_price_per_million cache_read_input_price_per_million
      alias cache_creation_input_price_per_million cache_write_input_price_per_million

      def cost_for(tokens)
        tokens = tokens.tokens if tokens.respond_to?(:tokens)

        Cost.new(tokens:, model: self)
      end

      def provider_class
        RubyLLM::Provider.resolve provider
      end

      def type
        output = modalities.output
        return 'embedding' if output.include?('embeddings')
        return 'moderation' if output.include?('moderation')
        return 'image' if output.include?('image')
        return 'audio' if output.include?('audio')
        return 'video' if output.include?('video')

        'chat'
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

      private

      def reasoning_options_from(data)
        data[:reasoning_options] || metadata[:reasoning_options] || metadata['reasoning_options']
      end

      def store_reasoning_options_metadata
        return unless reasoning_options.any?

        metadata.delete('reasoning_options')
        metadata[:reasoning_options] = reasoning_options
      end

      def normalize_reasoning_options(options)
        Array(options).filter_map do |option|
          next unless option.is_a?(Hash)

          normalized = option.to_h.transform_keys(&:to_sym)
          normalized[:type] = normalized[:type].to_s if normalized[:type]
          normalized[:values] = Array(normalized[:values]).map(&:to_s) if normalized.key?(:values)
          normalized
        end
      end
    end
  end
end

# frozen_string_literal: true

module RubyLLM
  # A Model describes one entry in the model registry: the model's identity,
  # capabilities, modalities, pricing, and provider metadata. Instances come
  # from the registry through RubyLLM.models and from Chat#model.
  #
  #   model = RubyLLM.models.find('gpt-5.4')
  #   model.name              # => "GPT-5.4"
  #   model.provider          # => "openai"
  #   model.context_window    # => 1050000
  #   model.supports?(:vision) # => true
  #
  class Model
    # The provider's identifier for the model, e.g. <tt>"gpt-5.4"</tt>.
    attr_reader :id

    # The human-readable model name, e.g. <tt>"GPT-5.4"</tt>.
    attr_reader :name

    # The provider slug as a String, e.g. <tt>"openai"</tt>.
    attr_reader :provider

    # The model family as a String, e.g. <tt>"gpt"</tt>, or +nil+.
    attr_reader :family

    # The model's release timestamp as a UTC Time, or +nil+.
    attr_reader :created_at

    # The maximum number of input tokens the model accepts, or +nil+.
    attr_reader :context_window

    # The maximum number of tokens the model can generate, or +nil+.
    attr_reader :max_output_tokens

    # The model's training data cutoff as a Date, or +nil+.
    attr_reader :knowledge_cutoff

    # The supported input and output modalities as a Model::Modalities object.
    #
    #   model.modalities.input   # => ["text", "image", "pdf"]
    #   model.modalities.output  # => ["text"]
    #
    attr_reader :modalities

    # The model's capability names as an array of Strings,
    # e.g. <tt>["function_calling", "streaming"]</tt>.
    attr_reader :capabilities

    # The model's pricing as a Model::Pricing object, in USD per million tokens.
    attr_reader :pricing

    # Provider-specific metadata as a Hash.
    attr_reader :metadata

    attr_reader :reasoning_options # :nodoc:

    def self.default(model_id, provider) # :nodoc:
      new(
        id: model_id,
        name: model_id.tr('-', ' ').capitalize,
        provider: provider,
        capabilities: %w[function_calling streaming vision structured_output],
        modalities: { input: %w[text image], output: %w[text] },
        metadata: { warning: 'Assuming model exists, capabilities may not be accurate' }
      )
    end

    def initialize(data) # :nodoc:
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

    # Returns whether #capabilities includes +capability+, given as a String
    # or Symbol.
    #
    #   model.supports?(:function_calling) # => true
    #
    def supports?(capability)
      capabilities.include?(capability.to_s)
    end

    # Returns the provider display name and model name combined,
    # e.g. <tt>"OpenAI - GPT-5.4"</tt>.
    def label
      provider_name = provider_class&.display_name || provider
      "#{provider_name} - #{name}"
    end

    def reasoning_option(type) # :nodoc:
      reasoning_options.find { |option| option[:type] == type.to_s }
    end

    def reasoning_option_values(type) # :nodoc:
      Array(reasoning_option(type)&.fetch(:values, nil))
    end

    # The standard text-token price columns, keyed by the symbol #price
    # accepts.
    PRICES = {
      input: :input,
      output: :output,
      cache_read: :cache_read_input,
      cache_write: :cache_write_input
    }.freeze
    private_constant :PRICES

    # Returns the standard text-token price for +kind+ in USD per million
    # tokens, or +nil+ if the registry has no such price. Valid kinds are
    # +:input+, +:output+, +:cache_read+, and +:cache_write+.
    #
    #   model.price(:input)   # => 2.5
    #   model.price(:output)  # => 10.0
    #
    def price(kind)
      column = PRICES.fetch(kind) do
        raise ArgumentError, "Unknown price kind: #{kind.inspect}. Valid kinds: #{PRICES.keys.join(', ')}"
      end
      pricing.text_tokens.public_send(column)
    end

    # Builds a Cost for +tokens+ (a Tokens object, or anything responding
    # to +tokens+) using this model's pricing.
    #
    #   cost = model.cost_for(response.tokens)
    #   puts cost.total
    #
    def cost_for(tokens)
      tokens = tokens.tokens if tokens.respond_to?(:tokens)

      Cost.new(tokens:, model: self)
    end

    # Returns the Provider class registered for this model's provider slug,
    # or +nil+ if no such provider is registered.
    def provider_class
      RubyLLM::Provider.resolve provider
    end

    # Returns the model's primary function, inferred from its output
    # modalities: <tt>"chat"</tt>, <tt>"embedding"</tt>, <tt>"moderation"</tt>,
    # <tt>"image"</tt>, <tt>"audio"</tt>, or <tt>"video"</tt>.
    def type
      output = modalities.output
      return 'embedding' if output.include?('embeddings')
      return 'moderation' if output.include?('moderation')
      return 'image' if output.include?('image')
      return 'audio' if output.include?('audio')
      return 'video' if output.include?('video')

      'chat'
    end

    def to_h # :nodoc:
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

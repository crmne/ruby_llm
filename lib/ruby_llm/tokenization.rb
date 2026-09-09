# frozen_string_literal: true

module RubyLLM
  # The token IDs produced by a model's tokenizer for plain text.
  # These exclude chat formatting, tools, and media, and do not measure
  # billable generation usage.
  class Tokenization
    include Support::Inspectable

    # The integer token IDs in text order.
    attr_reader :ids

    # The id of the model whose tokenizer was used.
    attr_reader :model

    # The provider's unmodified response, including token strings when available.
    attr_reader :raw

    # Tokenizes +text+ and returns a Tokenization. Most code calls
    # RubyLLM.tokenize. +model:+ defaults to the configured chat model;
    # +provider:+ selects its provider. +assume_model_exists:+ skips
    # registry lookup, and +context:+ supplies an isolated configuration.
    #
    #   result = RubyLLM.tokenize("Hello Ruby", model: "grok-4.3", provider: :xai)
    #   result.ids
    #   result.count
    #
    # Raises ArgumentError for non-string input and RubyLLM::Error when
    # the provider does not expose a tokenizer.
    def self.tokenize(text, model: nil, provider: nil, assume_model_exists: false, context: nil)
      raise ArgumentError, 'text must be a String' unless text.is_a?(String)

      config = context&.config || RubyLLM.config
      model ||= config.default_model
      model, provider_instance = Models.resolve(model, provider:, assume_model_exists:, config:)
      payload = { model: model.id, provider: provider_instance.slug }
      RubyLLM.instrument('tokenization.ruby_llm', payload, config:) do |event|
        result = provider_instance.tokenize(text, model:)
        event[:result] = result
        result
      end
    end

    def initialize(ids:, model:, raw: nil) # :nodoc:
      @ids = ids.dup.freeze
      @model = model
      @raw = raw
    end

    # Returns the number of tokens in the text.
    def count
      ids.length
    end

    def inspect_attributes # :nodoc:
      { model:, count: }
    end
  end
end

# frozen_string_literal: true

require 'time'

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
    attr_reader :id, :created_at, :display_name, :provider, :metadata,
                :context_window, :max_tokens, :supports_vision, :supports_functions,
                :supports_json_mode, :input_price_per_million, :output_price_per_million, :type, :family

    def initialize(data) # rubocop:disable Metrics/AbcSize,Metrics/MethodLength
      @id = data[:id]
      @created_at = data[:created_at].is_a?(String) ? Time.parse(data[:created_at]) : data[:created_at]
      @display_name = data[:display_name]
      @provider = data[:provider]
      @context_window = data[:context_window]
      @max_tokens = data[:max_tokens]
      @type = data[:type]
      @family = data[:family]
      @supports_vision = data[:supports_vision]
      @supports_functions = data[:supports_functions]
      @supports_json_mode = data[:supports_json_mode]
      @input_price_per_million = data[:input_price_per_million]
      @output_price_per_million = data[:output_price_per_million]
      @metadata = data[:metadata] || {}
    end

    def to_h # rubocop:disable Metrics/MethodLength
      {
        id: id,
        created_at: created_at&.iso8601,
        display_name: display_name,
        provider: provider,
        context_window: context_window,
        max_tokens: max_tokens,
        type: type,
        family: family,
        supports_vision: supports_vision,
        supports_functions: supports_functions,
        supports_json_mode: supports_json_mode,
        input_price_per_million: input_price_per_million,
        output_price_per_million: output_price_per_million,
        metadata: metadata
      }
    end
  end
end

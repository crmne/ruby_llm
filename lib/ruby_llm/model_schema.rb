# frozen_string_literal: true

require 'schematist'

module RubyLLM
  # Validation schema for entries in the model registry. The registry
  # builder validates refreshed registries against it before publishing,
  # and the spec suite validates the bundled models.json.
  class ModelSchema < Schematist::Schema # :nodoc:
    CAPABILITIES = %w[
      streaming function_calling tool_choice parallel_tool_calls
      structured_output predicted_outputs
      distillation fine_tuning batch realtime image_generation
      speech_generation transcription translation citations reasoning
      caching moderation json_mode vision video
    ].freeze

    description 'A model entry in the RubyLLM model registry'

    string :id, description: 'Unique identifier for the model'
    string :name, description: 'Display name of the model'
    string :provider, description: 'Provider of the model (e.g., openai, anthropic, mistral)'

    any_of :family, required: false, description: 'Model family (e.g., gpt-4, claude-3)' do
      string
      null
    end

    # Ruby Time#to_s strings today, not ISO8601; normalize at write time
    # before tightening this to format: 'date-time'.
    any_of :created_at, required: false, description: 'Creation date of the model' do
      string
      null
    end

    any_of :context_window, description: 'Maximum context window size' do
      integer minimum: 0
      null
    end

    any_of :max_output_tokens, description: 'Maximum output tokens' do
      integer minimum: 0
      null
    end

    any_of :knowledge_cutoff, required: false, description: 'Knowledge cutoff date' do
      string format: 'date'
      null
    end

    object :modalities, required: false do
      array :input, description: 'Supported input modalities' do
        string enum: Models::MODELS_DEV_INPUT_MODALITIES
      end
      array :output, description: 'Supported output modalities' do
        string enum: Models::MODELS_DEV_OUTPUT_MODALITIES
      end
    end

    array :capabilities, required: false, description: 'Model capabilities' do
      string enum: CAPABILITIES
    end

    object :pricing, required: false, description: 'Pricing information for the model' do
      Model::Pricing::CATEGORIES.each do |category|
        object category, required: false do
          Model::PricingCategory::TIERS.each do |tier|
            object tier, required: false do
              Model::PricingTier::ATTRIBUTES.each do |attribute|
                number attribute, minimum: 0, required: false
              end
            end
          end
          integer :long_context_threshold,
                  minimum: 0,
                  required: false,
                  description: 'Prompt size above which long_context rates apply'
        end
      end
    end

    object :metadata, required: false, description: 'Additional metadata about the model' do
      additional_properties true
    end

    # The Draft 2020-12 JSON Schema document for one model entry. Wrap it in an
    # array schema to validate a whole registry.
    def self.json_schema
      new.to_json_schema
    end
  end
end

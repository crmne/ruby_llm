# frozen_string_literal: true

module RubyLLM
  # Represents a generated image from an AI model.
  # Provides an interface to image generation capabilities
  # from providers like DALL-E and Gemini's Imagen.
  class Image
    attr_reader :url, :data, :mime_type, :revised_prompt, :model, :usage

    def initialize(model:, url: nil, data: nil, mime_type: nil, revised_prompt: nil, usage: {})
      @url = url
      @data = data
      @mime_type = mime_type
      @revised_prompt = revised_prompt
      @usage = usage
      @model = model
    end

    def base64?
      !@data.nil?
    end

    # Returns the raw binary image data regardless of source
    def to_blob
      if base64?
        Base64.decode64(@data)
      else
        # Use Faraday instead of URI.open for better security
        response = Faraday.get(@url)
        response.body
      end
    end

    # Saves the image to a file path
    def save(path)
      File.binwrite(File.expand_path(path), to_blob)
      path
    end

    def self.paint(prompt, # rubocop:disable Metrics/ParameterLists
                   model: nil,
                   provider: nil,
                   assume_model_exists: false,
                   size: '1024x1024',
                   context: nil)
      config = context&.config || RubyLLM.config
      model ||= config.default_image_model
      model, provider = Models.resolve(model, provider: provider, assume_exists: assume_model_exists)
      model_id = model.id

      provider = Provider.for(model_id) if provider.nil?
      connection = context ? context.connection_for(provider) : provider.connection(config)
      provider.paint(prompt, model: model_id, size:, connection:)
    end

    def self.edit(prompt, # rubocop:disable Metrics/ParameterLists,Metrics/CyclomaticComplexity
                  model: nil,
                  provider: nil,
                  assume_model_exists: false,
                  context: nil,
                  with: {},
                  options: {})
      config = context&.config || RubyLLM.config
      model, provider = Models.resolve(model, provider: provider, assume_exists: assume_model_exists) if model
      model_id = model&.id || config.default_image_model

      provider = Provider.for(model_id) if provider.nil?
      connection = context ? context.connection_for(provider) : provider.connection(config)
      provider.edit(prompt, model: model_id, with:, connection:, options:)
    end

    def total_cost
      input_cost + output_cost
    end

    def model_info
      @model_info ||= RubyLLM.models.find(model)
    end

    def input_cost
      usage['input_tokens'] * model_info.input_price_per_million / 1_000_000
    end

    def output_cost
      usage['output_tokens'] * model_info.output_price_per_million / 1_000_000
    end
  end
end

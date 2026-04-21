# frozen_string_literal: true

module RubyLLM
  # Represents a generated image from an AI model.
  class Image
    attr_reader :url, :data, :mime_type, :revised_prompt, :model_id

    def initialize(url: nil, data: nil, mime_type: nil, revised_prompt: nil, model_id: nil)
      @url = url
      @data = data
      @mime_type = mime_type
      @revised_prompt = revised_prompt
      @model_id = model_id
    end

    def base64?
      !@data.nil?
    end

    def to_blob
      if base64?
        Base64.decode64 @data
      else
        response = Connection.basic.get @url
        response.body
      end
    end

    def save(path)
      File.binwrite(File.expand_path(path), to_blob)
      path
    end

    # Generate an image from a text prompt.
    #
    # @param prompt [String] the description of the image to generate
    # @param model [String, nil] the image model to use (defaults to config.default_image_model)
    # @param provider [Symbol, nil] force a specific provider
    # @param assume_model_exists [Boolean] skip the model registry check
    # @param size [String] image dimensions (provider-dependent; ignored by providers that do not support it)
    # @param context [RubyLLM::Context, nil] per-call configuration override
    # @param with [Hash] provider-specific parameters merged into the API payload as-is
    #   (e.g. quality: "medium", output_format: "jpeg" for OpenAI gpt-image-1,
    #   or personGeneration: "ALLOW_ADULT" for Gemini imagen). Not validated
    #   client-side; the provider API will either use or reject unknown keys.
    # @return [RubyLLM::Image]
    def self.paint(prompt, # rubocop:disable Metrics/ParameterLists
                   model: nil,
                   provider: nil,
                   assume_model_exists: false,
                   size: '1024x1024',
                   context: nil,
                   with: {})
      config = context&.config || RubyLLM.config
      model ||= config.default_image_model
      model, provider_instance = Models.resolve(model, provider: provider, assume_exists: assume_model_exists,
                                                       config: config)
      model_id = model.id

      provider_instance.paint(prompt, model: model_id, size:, params: with)
    end
  end
end

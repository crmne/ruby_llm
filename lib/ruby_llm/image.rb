# frozen_string_literal: true

module RubyLLM
  # Represents a generated image from an AI model.
  class Image
    include Blobbable

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

    def self.paint(prompt, # rubocop:disable Metrics/ParameterLists
                   model: nil,
                   provider: nil,
                   assume_model_exists: false,
                   context: nil,
                   **model_params)
      config = context&.config || RubyLLM.config
      model ||= config.default_image_model
      model, provider_instance = Models.resolve(model, provider: provider, assume_exists: assume_model_exists,
                                                       config: config)
      model_id = model.id

      provider_instance.paint(prompt, model: model_id, **model_params)
    end
  end
end

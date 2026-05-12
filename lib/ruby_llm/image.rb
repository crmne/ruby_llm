# frozen_string_literal: true

module RubyLLM
  # Represents a generated image from an AI model.
  class Image
    attr_reader :url, :data, :mime_type, :revised_prompt, :model_id, :usage

    def initialize(url: nil, data: nil, mime_type: nil, revised_prompt: nil, model_id: nil, usage: {}) # rubocop:disable Metrics/ParameterLists
      @url = url
      @data = data
      @mime_type = mime_type
      @revised_prompt = revised_prompt
      @model_id = model_id
      @usage = usage
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

    def self.paint(prompt, # rubocop:disable Metrics/ParameterLists
                   model: nil,
                   provider: nil,
                   assume_model_exists: false,
                   size: '1024x1024',
                   context: nil,
                   with: nil,
                   mask: nil,
                   params: {})
      config = context&.config || RubyLLM.config
      model ||= config.default_image_model
      model, provider_instance = Models.resolve(model, provider: provider, assume_exists: assume_model_exists,
                                                       config: config)
      model_id = model.id

      provider_instance.paint(prompt, model: model_id, size:, with:, mask:, params:)
    end

    def tokens
      @tokens ||= Tokens.build(
        input: usage_value('input_tokens'),
        output: usage_value('output_tokens')
      )
    end

    def cost
      Cost.new(tokens:, model: model_info, category: :images, input_details: input_tokens_details)
    end

    def model_info
      return unless model_id

      @model_info ||= RubyLLM.models.find(model_id)
    rescue ModelNotFoundError
      nil
    end

    private

    def input_tokens_details
      usage_value('input_tokens_details')
    end

    def usage_value(key)
      usage[key] || usage[key.to_sym]
    end
  end
end

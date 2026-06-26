# frozen_string_literal: true

require 'base64'

module RubyLLM
  # Represents a generated image from an AI model.
  class Image
    attr_reader :url, :data, :mime_type, :revised_prompt, :model_id, :usage

    def self.paint(prompt, # rubocop:disable Metrics/ParameterLists
                   model: nil,
                   provider: nil,
                   assume_model_exists: false,
                   size: '1024x1024',
                   context: nil,
                   with: nil,
                   mask: nil,
                   params: {},
                   metadata: nil)
      config = context&.config || RubyLLM.config
      model ||= config.default_image_model
      model, provider_instance = Models.resolve(model, provider: provider, assume_exists: assume_model_exists,
                                                       config: config)
      payload = {
        provider: provider_instance.slug,
        provider_class: provider_instance.class.display_name,
        model: model.id,
        model_info: model,
        prompt: prompt,
        size: size,
        metadata: Metadata.coerce(metadata)
      }

      RubyLLM.instrument('image.ruby_llm', payload, config: config) do |event|
        result = provider_instance.paint(prompt, model: model.id, size:, with:, mask:, params:)
        event[:result] = result
        event[:response_model] = result.model_id
        result
      end
    end

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

    def tokens
      @tokens ||= Tokens.build(
        input: usage['input_tokens'],
        output: usage['output_tokens']
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
      usage['input_tokens_details']
    end
  end
end

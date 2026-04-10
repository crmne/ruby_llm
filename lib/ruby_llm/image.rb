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

    def total_cost
      input_cost + output_cost
    end

    def input_cost
      return flat_input_cost unless detailed_input_usage?

      text_input_cost + image_input_cost
    end

    def output_cost
      tokens_for('output_tokens') * output_token_price.to_f / 1_000_000
    end

    def model_info
      @model_info ||= RubyLLM.models.find(model_id)
    end

    private

    def flat_input_cost
      tokens_for('input_tokens') * model_info.input_price_per_million.to_f / 1_000_000
    end

    def text_input_cost
      input_detail('text_tokens') * model_info.input_price_per_million.to_f / 1_000_000
    end

    def image_input_cost
      input_detail('image_tokens') * image_input_token_price.to_f / 1_000_000
    end

    def output_token_price
      model_info.pricing.images.output || model_info.output_price_per_million
    end

    def image_input_token_price
      model_info.pricing.images.input || model_info.input_price_per_million
    end

    def detailed_input_usage?
      usage['input_tokens_details'].is_a?(Hash)
    end

    def input_detail(key)
      usage.dig('input_tokens_details', key).to_i
    end

    def tokens_for(key)
      usage[key].to_i
    end
  end
end

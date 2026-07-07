# frozen_string_literal: true

require 'base64'

module RubyLLM
  # An Image is the result of an image generation request. It holds either
  # a hosted URL or inline Base64 data, depending on the provider, along
  # with the model id and token usage of the call.
  #
  #   image = RubyLLM.paint("a sunset over mountains in watercolor style")
  #   image.save("sunset.png")
  #
  class Image
    # The URL of the hosted image, for providers that return one, or +nil+.
    attr_reader :url

    # The Base64-encoded image data, for providers that return the image
    # inline, or +nil+.
    attr_reader :data

    # The MIME type of the image data, such as <tt>"image/png"</tt>.
    attr_reader :mime_type

    # The provider's rewritten version of the prompt, when reported.
    attr_reader :revised_prompt

    # The id of the model that generated the image.
    attr_reader :model

    # Generates an image from +prompt+ and returns an Image. Most code
    # calls this through RubyLLM.paint.
    #
    # +model:+ selects the image model and defaults to the configured
    # +default_image_model+. +provider:+ forces a specific provider, and
    # +assume_model_exists:+ skips the registry lookup, which is useful
    # for custom endpoints. +size:+ requests dimensions on models that
    # support it. +with:+ passes one or more source images for editing,
    # and +mask:+ constrains which parts of the image may change.
    # +provider_options:+ takes options in the provider's request
    # vocabulary and merges them into the request as-is. +context:+
    # supplies a Context whose configuration replaces the global one.
    # +metadata:+ is included in the instrumentation payload.
    #
    #   image = RubyLLM.paint("A small watercolor robot", model: "gpt-image-1")
    #
    #   RubyLLM.paint(
    #     "Turn the logo green and keep the background transparent",
    #     model: "gpt-image-1",
    #     with: "logo.png"
    #   )
    #
    def self.paint(prompt, # rubocop:disable Metrics/ParameterLists
                   model: nil,
                   provider: nil,
                   assume_model_exists: false,
                   size: '1024x1024',
                   context: nil,
                   with: nil,
                   mask: nil,
                   provider_options: {},
                   metadata: nil)
      config = context&.config || RubyLLM.config
      model ||= config.default_image_model
      model, provider_instance = Models.resolve(model, provider: provider, assume_model_exists: assume_model_exists,
                                                       config: config)
      payload = {
        provider: provider_instance.slug,
        provider_class: provider_instance.class.display_name,
        model: model.id,
        model_info: model,
        prompt: prompt,
        size: size,
        provider_options: provider_options,
        metadata: metadata
      }

      RubyLLM.instrument('image.ruby_llm', payload, config: config) do |event|
        result = provider_instance.paint(prompt, model:, size:, with:, mask:, provider_options:)
        event[:result] = result
        event[:response_model] = result.model
        result
      end
    end

    # :stopdoc:
    def initialize(url: nil, data: nil, mime_type: nil, revised_prompt: nil, model: nil, usage: {}) # rubocop:disable Metrics/ParameterLists
      @url = url
      @data = data
      @mime_type = mime_type
      @revised_prompt = revised_prompt
      @model = model
      @usage = usage
    end
    # :startdoc:

    # Returns +true+ if the image holds inline Base64 data, +false+ otherwise.
    def base64?
      !@data.nil?
    end

    # Returns the raw binary image bytes, decoding #data when present or
    # downloading from #url otherwise.
    #
    #   File.binwrite("image.png", image.to_blob)
    #
    def to_blob
      if base64?
        Base64.decode64 @data
      else
        response = Connection.basic.get @url
        response.body
      end
    end

    # Writes the binary image to +path+, expanding it first. Returns
    # +path+ as given.
    #
    #   image.save("steampunk_owl.png")
    #
    def save(path)
      File.binwrite(File.expand_path(path), to_blob)
      path
    end

    # Returns a Tokens with the input and output token counts reported
    # by the provider, or +nil+ when the provider reported none.
    #
    #   image.tokens.input
    #   image.tokens.output
    #
    def tokens
      @tokens ||= Tokens.build(
        input: usage['input_tokens'],
        output: usage['output_tokens']
      )
    end

    # Returns a Cost for the generation, priced from the model registry.
    #
    #   image.cost.total
    #
    def cost
      Cost.new(tokens:, model: model_info, category: :images, input_details: input_tokens_details)
    end

    # Returns the registry Model for #model, or +nil+ if the model id
    # is missing or not in the registry.
    def model_info
      return unless model

      @model_info ||= RubyLLM.models.find(model)
    rescue ModelNotFoundError
      nil
    end

    private

    attr_reader :usage

    def input_tokens_details
      usage['input_tokens_details']
    end
  end
end

# frozen_string_literal: true

require 'base64'

module RubyLLM
  # An Image is a generated or edited image. Save it to a file with #save
  # or read its bytes with #to_blob. Both handle hosted URLs and inline data.
  #
  #   image = RubyLLM.paint("a sunset over mountains in watercolor style")
  #   image.save("sunset.png")
  #
  class Image
    include Support::Inspectable
    include Files::Saving
    include Accounting::Usage::Result
    include Accounting::Usage::ModelInfo

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
    # support it. +count:+ asks for several images in one request, returning
    # an Array of Images instead of one. +with:+ passes one or more source
    # images for editing, and +mask:+ constrains which parts of the image
    # may change. +provider_options:+ takes options in the provider's
    # request vocabulary and merges them into the request as-is.
    # +context:+ supplies a Context whose configuration replaces the
    # global one. +metadata:+ is included in the instrumentation payload.
    # +owner:+ attributes the usage to a record, such as a user, and wins
    # over RubyLLM.with_owner.
    #
    #   image = RubyLLM.paint("A small watercolor robot", model: "gpt-image-2")
    #
    #   images = RubyLLM.paint("A small watercolor robot", count: 4)
    #   images.each_with_index { |image, i| image.save("robot-#{i}.png") }
    #
    #   RubyLLM.paint(
    #     "Turn the logo green and keep the background transparent",
    #     model: "gpt-image-2",
    #     with: "logo.png"
    #   )
    #
    # Providers that cannot generate several images in one request raise
    # ArgumentError when +count:+ is above 1.
    #
    # +fallbacks:+ lists models to try, in order, when the request fails
    # with one of the errors Chat#with_fallbacks moves on from by default,
    # such as a rate limit or an overloaded provider. Each is a model id or
    # a Model, and gets the same request. A fallback whose model can't be
    # found is skipped. Each attempt has its own +image.ruby_llm+ event
    # and usage entry.
    #
    #   RubyLLM.paint("A small watercolor robot", model: "gpt-image-2",
    #                 fallbacks: ["gemini-3.1-flash-image"])
    #
    def self.paint(prompt,
                   model: nil,
                   provider: nil,
                   assume_model_exists: false,
                   size: nil,
                   count: nil,
                   context: nil,
                   with: nil,
                   mask: nil,
                   provider_options: {},
                   metadata: nil,
                   owner: nil,
                   fallbacks: [])
      queue = Array(fallbacks).flatten.compact.map { |fallback| Fallback.build(fallback) }
      operation = painting(model, provider:, assume_model_exists:, context:, owner:)
      begin
        with_fallback_ready(queue) do
          operation.run(prompt:, size:, count:, provider_options:, metadata:) do |provider_instance, image_model|
            provider_instance.paint(prompt, model: image_model, size:, count:, with:, mask:, provider_options:)
          end
        end
      rescue StandardError => e
        raise unless Fallback.error?(e, Fallback::DEFAULT_ERRORS)

        _, operation = Fallback.next_usable(queue) do |fallback|
          painting(fallback.id, provider: fallback.provider, context:, owner:, resolved: fallback.model)
        end
        raise e unless operation

        retry
      end
    end

    # While a fallback is left, a timeout, a failed connection, or a long
    # retry wait moves on to it instead of retrying the same model, as
    # Chat#with_fallbacks does. Every error the transport retries is one
    # paint falls back on, so the fallback takes each of them.
    def self.with_fallback_ready(queue, &)
      return yield if queue.empty?

      Transport::Connection.with_fallback_ready(->(_error) { true }, &)
    end
    private_class_method :with_fallback_ready

    def self.painting(model, provider:, context:, owner:, assume_model_exists: false, resolved: nil) # :nodoc:
      Accounting::Operation.new(
        'image', model, default: :default_image_model, category: :images, provider:, assume_model_exists:, context:,
                        owner:, resolved:,
                        report: lambda { |event, result|
                          images = Support::Utils.to_safe_array(result)
                          event[:result] = result
                          event[:response_model] = images.first&.model
                          event[:tokens] = Tokens.aggregate(images.map(&:tokens))
                          event[:cost] = Cost.aggregate(images.map(&:cost))
                        }
      )
    end
    private_class_method :painting

    # :stopdoc:

    # Set by the protocol that generated the image, so a Context's
    # connection settings reach #to_blob.
    attr_writer :config

    def config
      @config || RubyLLM.config
    end

    def initialize(url: nil, data: nil, mime_type: nil, revised_prompt: nil, model: nil, usage: {})
      @url = url
      @data = data
      @mime_type = mime_type
      @revised_prompt = revised_prompt
      @model = model
      @raw_usage = usage
    end
    # :startdoc:

    # Returns +true+ if the image holds inline Base64 data, +false+ otherwise.
    def base64?
      !@data.nil?
    end

    # Returns the raw binary image bytes, decoding #data when present or
    # downloading from #url otherwise.
    #
    #   image_bytes = image.to_blob
    #
    def to_blob
      if base64?
        Base64.decode64 @data
      else
        Transport::Connection.download(@url, config)
      end
    end

    ##
    # :method: save
    # :call-seq:
    #   save(path)
    #
    # Writes the binary image to +path+, expanding it first. Returns
    # +path+ as given.
    #
    #   image.save("steampunk_owl.png")

    # Returns a Tokens with usage across every provider attempt.
    # Its fields are +nil+ when none were reported.
    #
    #   image.tokens.input
    #   image.tokens.output
    #
    def tokens
      return ruby_llm_usage_tokens unless ruby_llm_usage_entries.empty?

      @tokens ||= Tokens.new(
        input: raw_usage['input_tokens'],
        output: raw_usage['output_tokens'],
        cache_read: raw_usage['cache_read_tokens'],
        reported_cost: raw_usage['cost']
      )
    end

    # Returns a Cost across every provider attempt, using reported prices
    # when available and registry pricing otherwise.
    #
    #   image.cost.total
    #
    def cost
      return ruby_llm_usage_cost unless ruby_llm_usage_entries.empty?

      Cost.new(tokens:, model: model_info, category: :images, input_details: input_tokens_details)
    end

    # Returns the image's Model from its provider's registry, falling back
    # to the requested model when the response ID is unknown. Images built
    # without a request look up #model, or return +nil+ if unknown.
    def model_info
      super if model
    end

    private

    attr_reader :raw_usage

    def input_tokens_details
      raw_usage['input_tokens_details']
    end

    def inspect_attributes # :nodoc:
      {
        model: model,
        mime_type: mime_type,
        url: url,
        data: data && "#{data.bytesize} bytes",
        revised_prompt: revised_prompt
      }
    end
  end
end

# frozen_string_literal: true

module RubyLLM
  # A Video is the result of a video generation request. It holds either a
  # hosted URL or the raw video bytes, depending on the provider, along
  # with the model id and MIME type of the clip.
  #
  #   video = RubyLLM.animate("a paper boat sailing down a rainy gutter")
  #   video.save("boat.mp4")
  #
  class Video
    include Inspectable

    # The URL of the hosted video, for providers that return one, or +nil+.
    attr_reader :url

    # The raw video bytes, for providers whose videos require an
    # authenticated download, or +nil+ when the video is hosted at #url.
    attr_reader :data

    # The MIME type of the video, such as <tt>"video/mp4"</tt>.
    attr_reader :mime_type

    # The id of the model that generated the video.
    attr_reader :model

    # The clip length in seconds, when the provider reports one.
    attr_reader :duration

    # The provider's raw job response, for provider-specific fields such
    # as reported cost.
    attr_reader :raw

    # Generates a video from +prompt+, blocks until the provider finishes
    # rendering it, and returns a Video. Most code calls this through
    # RubyLLM.animate. Video generation is asynchronous on every provider,
    # so this submits a job with VideoJob.animate_later and polls until it
    # is done, honoring <tt>config.video_generation_timeout</tt> and
    # <tt>config.video_generation_poll_interval</tt>.
    #
    # +model:+ selects the video model and defaults to the configured
    # +default_video_model+. +provider:+ forces a specific provider, and
    # +assume_model_exists:+ skips the registry lookup. +with:+ passes a
    # reference image for image-to-video generation on models that support
    # it. +provider_options:+ takes options in the provider's request
    # vocabulary, such as durations and resolutions, and merges them into
    # the request as-is. +context:+ supplies a Context whose configuration
    # replaces the global one. +metadata:+ is included in the
    # instrumentation payload.
    #
    #   video = RubyLLM.animate("a hummingbird in slow motion", model: "veo-3.1-fast-generate-preview")
    #
    #   RubyLLM.animate(
    #     "Make the waterfall crash down",
    #     model: "grok-imagine-video",
    #     with: "waterfall.png",
    #     provider_options: { duration: 5 }
    #   )
    #
    def self.animate(prompt,
                     model: nil,
                     provider: nil,
                     assume_model_exists: false,
                     context: nil,
                     with: nil,
                     provider_options: {},
                     metadata: nil)
      config = context&.config || RubyLLM.config
      payload = { model:, prompt:, provider_options:, metadata: }

      RubyLLM.instrument('video.ruby_llm', payload, config: config) do |event|
        job = VideoJob.animate_later(prompt, model:, provider:, assume_model_exists:,
                                             context:, with:, provider_options:, metadata:)
        event[:model] = job.model
        event[:job_id] = job.id
        job.wait!
        result = job.video
        event[:result] = result
        event[:response_model] = result.model
        result
      end
    end

    # Set by the protocol that generated the video, so a Context's
    # connection settings reach #to_blob.
    attr_writer :config # :nodoc:

    def config # :nodoc:
      @config || RubyLLM.config
    end

    def initialize(url: nil, data: nil, mime_type: nil, model: nil, duration: nil, raw: nil) # :nodoc:
      @url = url
      @data = data
      @mime_type = mime_type
      @model = model
      @duration = duration
      @raw = raw
    end

    # Returns the raw binary video bytes, downloading from #url when the
    # provider returned a hosted video.
    #
    #   File.binwrite("clip.mp4", video.to_blob)
    #
    def to_blob
      data || Connection.basic(config).get(url).body
    end

    # Writes the binary video to +path+, expanding it first. Returns
    # +path+ as given.
    #
    #   video.save("clip.mp4")
    #
    def save(path)
      File.binwrite(File.expand_path(path), to_blob)
      path
    end

    private

    def inspect_attributes # :nodoc:
      {
        model: model,
        mime_type: mime_type,
        url: url,
        data: data && "#{data.bytesize} bytes",
        duration: duration
      }
    end
  end
end

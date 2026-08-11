# frozen_string_literal: true

module RubyLLM
  # A VideoJob is an in-flight video generation. RubyLLM.animate_later
  # returns one immediately; poll it with #refresh! and read the finished
  # clip with #video. RubyLLM.animate runs the same job through #wait!.
  #
  #   job = RubyLLM.animate_later("a paper boat sailing down a gutter")
  #   job.refresh! until job.done?
  #   job.video.save("boat.mp4")
  #
  class VideoJob
    include Inspectable

    # The provider's id for the job.
    attr_reader :id

    # The job state: +:pending+, +:completed+, or +:failed+.
    attr_reader :status

    # The id of the model rendering the video.
    attr_reader :model

    # The provider's failure message when #failed?, or +nil+.
    attr_reader :error

    # The provider's raw response from the last submit or poll.
    attr_reader :raw

    # Submits a video generation job and returns a VideoJob without
    # waiting for the result. Most code calls this through
    # RubyLLM.animate_later. Takes the same arguments as Video.animate.
    #
    #   job = RubyLLM.animate_later("a hummingbird in slow motion")
    #   job.id      # => "0eb6910f-a353-4699-9d1e-6a4f7a5b39e2"
    #   job.done?   # => false
    #
    def self.animate_later(prompt,
                           model: nil,
                           provider: nil,
                           assume_model_exists: false,
                           context: nil,
                           with: nil,
                           provider_options: {},
                           metadata: nil)
      config = context&.config || RubyLLM.config
      model ||= config.default_video_model
      model, provider_instance = Models.resolve(model, provider: provider, assume_model_exists: assume_model_exists,
                                                       config: config)
      payload = {
        provider: provider_instance.slug,
        provider_class: provider_instance.class.display_name,
        model: model.id,
        model_info: model,
        prompt: prompt,
        provider_options: provider_options,
        metadata: metadata
      }

      RubyLLM.instrument('video_job.ruby_llm', payload, config: config) do |event|
        job = provider_instance.animate_later(prompt, model:, with:, provider_options:)
        event[:job_id] = job.id
        job
      end
    end

    def initialize(id:, protocol:, model: nil, status: :pending, raw: nil, error: nil) # :nodoc:
      @id = id
      @protocol = protocol
      @model = model
      @status = status
      @raw = raw
      @error = error
    end

    # Returns +true+ while the provider is still rendering the video.
    def pending?
      status == :pending
    end

    # Returns +true+ once the job finished, successfully or not.
    def done?
      !pending?
    end

    # Returns +true+ when the job finished with a video.
    def completed?
      status == :completed
    end

    # Returns +true+ when the job finished without a video. #error carries
    # the provider's failure message.
    def failed?
      status == :failed
    end

    # Re-fetches the job from the provider, updating #status, #error, and
    # #raw. Does nothing once the job is #done?. Returns self.
    def refresh!
      return self if done?

      state = @protocol.refresh_video_job(self)
      @status = state.fetch(:status)
      @raw = state[:raw]
      @error = state[:error]
      self
    end

    # Polls the job until it finishes, then returns self. Raises Error
    # when the job fails or +timeout+ elapses first. +timeout+ and
    # +interval+ are seconds and default to the configured
    # +video_generation_timeout+ and +video_generation_poll_interval+.
    def wait!(timeout: nil, interval: nil)
      timeout ||= @protocol.config.video_generation_timeout
      interval ||= @protocol.config.video_generation_poll_interval
      deadline = monotonic_time + timeout

      until done?
        raise Error, "Video generation timed out after #{timeout} seconds" if monotonic_time > deadline

        sleep interval
        refresh!
      end
      raise Error, "Video generation failed: #{error}" if failed?

      self
    end

    # Returns the finished Video, downloading it from the provider when
    # its API requires that. Returns +nil+ while #pending? and raises
    # Error when #failed?.
    def video
      raise Error, "Video generation failed: #{error}" if failed?
      return unless completed?

      @video ||= @protocol.download_video(self)
    end

    private

    def monotonic_time
      Process.clock_gettime(Process::CLOCK_MONOTONIC)
    end

    def inspect_attributes # :nodoc:
      { id: id, status: status, model: model }
    end
  end
end

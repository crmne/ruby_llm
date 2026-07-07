# frozen_string_literal: true

module RubyLLM
  # A Protocol knows how to talk to a family of provider APIs: rendering
  # request payloads, parsing responses, streaming chunks, and naming the
  # endpoints involved. Its counterpart, Provider, knows where to talk and
  # who it is. The protocols that ship with the gem live under
  # RubyLLM::Protocols.
  #
  # Subclass Protocol, or a shipped subclass such as
  # RubyLLM::Protocols::ChatCompletions, to support a new wire format. Each
  # operation (chat, embeddings, moderation, image generation, speech,
  # transcription, and model listing) is served by three kinds of seam method
  # you override:
  #
  # - <tt>render_*</tt> serializes a RubyLLM request into the wire payload,
  #   such as +render_payload+ for chat or +render_embedding_payload+.
  # - <tt>*_url</tt> names the endpoint, such as +completion_url+ or
  #   +embedding_url+.
  # - <tt>parse_*</tt> turns the wire response back into RubyLLM objects, such
  #   as +parse_completion_body+ or +parse_embedding_response+.
  #
  # Override the seams for the operations you support; the rest raise
  # NotImplementedError. For example:
  #
  #   class ChatCompletions < RubyLLM::Protocols::ChatCompletions
  #     def completion_url
  #       'v2/chat'
  #     end
  #   end
  #
  # A protocol instance is constructed by its Provider and borrows the
  # provider's Connection, so subclasses never build HTTP clients
  # themselves.
  class Protocol
    include Streaming

    # The Provider this protocol talks through.
    attr_reader :provider

    # The provider's Configuration.
    attr_reader :config

    # The provider's HTTP connection. Subclasses use it to reach their
    # endpoints.
    attr_reader :connection

    # The Model this instance targets, or +nil+ for model-less operations
    # such as listing models.
    attr_reader :model

    # :stopdoc:

    # Declares seam methods that raise NotImplementedError until a subclass
    # overrides them: render_* serializes a request to wire form, *_url names an
    # endpoint, and parse_* reads a wire response back into RubyLLM objects.
    def self.abstract(*names)
      names.each do |name|
        define_method(name) do |*_args, **_opts|
          raise NotImplementedError, "#{self.class} must implement ##{name}"
        end
      end
    end

    abstract :render_payload, :completion_url, :parse_completion_body
    abstract :models_url, :parse_list_models_response
    abstract :render_embedding_payload, :embedding_url, :parse_embedding_response
    abstract :render_moderation_payload, :moderation_url, :parse_moderation_response
    abstract :render_image_payload, :images_url, :parse_image_response
    abstract :render_speech_payload, :speech_url, :parse_speech_response
    abstract :render_transcription_payload, :transcription_url, :parse_transcription_response

    def initialize(provider, model = nil)
      @provider = provider
      @config = provider.config
      @connection = provider.connection
      @model = model
    end

    # rubocop:disable Metrics/ParameterLists

    def complete(messages, tools:, temperature:, provider_options: {}, headers: {}, schema: nil, thinking: nil,
                 max_output_tokens: nil, citations: false, caching: nil, tool_prefs: nil, before_request: [], &)
      payload = render(
        messages, tools:, tool_prefs:, temperature:, max_output_tokens:, provider_options:, schema:, thinking:,
                  citations:, caching:, before_request:, stream: block_given?
      )

      if block_given?
        stream_response payload, headers, &
      else
        sync_response payload, headers
      end
    end

    def render(messages, tools:, temperature:, provider_options: {}, schema: nil, thinking: nil,
               max_output_tokens: nil, citations: false, caching: nil, tool_prefs: nil, before_request: [],
               stream: false)
      payload = Utils.deep_merge(
        render_payload(
          messages,
          tools: tools,
          tool_prefs: tool_prefs,
          temperature: maybe_normalize_temperature(temperature, model),
          max_output_tokens: max_output_tokens,
          model: model,
          stream: stream,
          schema: schema,
          thinking: thinking,
          citations: citations,
          caching: caching
        ),
        provider_options
      )
      apply_before_request_hooks(payload, before_request)
    end
    # rubocop:enable Metrics/ParameterLists

    def list_models
      response = @connection.get models_url
      parse_list_models_response response, @provider.slug, @provider.capabilities
    end

    def embed(text, model:, dimensions:, task_type: nil, title: nil, provider_options: {}) # rubocop:disable Metrics/ParameterLists
      payload = render_embedding_payload(text, model:, dimensions:, task_type:, title:, provider_options:)
      response = @connection.post(embedding_url(model:), payload)
      parse_embedding_response(response, model:, text:)
    end

    def moderate(input, model:, provider_options: {})
      payload = render_moderation_payload(input, model:, provider_options:)
      response = @connection.post moderation_url, payload
      parse_moderation_response(response, model:)
    end

    def paint(prompt, model:, size:, with: nil, mask: nil, provider_options: {}) # rubocop:disable Metrics/ParameterLists
      validate_paint_inputs!(with:, mask:)
      payload = render_image_payload(prompt, model:, size:, with:, mask:, provider_options:)
      response = @connection.post images_url(with:, mask:), payload
      parse_image_response(response, model:)
    end

    def speak(input, model:, voice:, format:, provider_options: {})
      payload = render_speech_payload(input, model:, voice:, format:, provider_options:)
      response = @connection.post speech_url(model:), payload
      parse_speech_response(response, model:, voice:, format:)
    end

    def transcribe(audio_file, model:, language:, format: nil, speaker_names: nil, # rubocop:disable Metrics/ParameterLists
                   speaker_references: nil, provider_options: {}, prompt: nil, temperature: nil)
      file_part = build_audio_file_part(audio_file)
      payload = render_transcription_payload(file_part, model:, language:, format:, speaker_names:,
                                                        speaker_references:, provider_options:, prompt:,
                                                        temperature:)
      response = @connection.post transcription_url, payload
      parse_transcription_response(response, model:)
    end

    def maybe_normalize_temperature(temperature, _model)
      temperature
    end

    def parse_error(response)
      @provider.parse_error(response)
    end

    def preprocess_message(message)
      return message unless auto_upload_large_files?
      return message unless message.role == :user
      return message if message.attachments.empty?

      uploaded = message.attachments.map { |attachment| preprocess_attachment(attachment) }
      return message if uploaded == message.attachments

      message.with_attachments(uploaded)
    end

    private

    def apply_before_request_hooks(payload, hooks)
      Array(hooks).each { |hook| hook.call(payload) }
      payload
    end

    def auto_upload_large_files?
      @config.auto_upload_large_files && @provider.files? && supports_provider_file_references?
    end

    def supports_provider_file_references?
      false
    end

    def preprocess_attachment(attachment)
      return attachment if attachment.provider_file?
      return attachment unless upload_large_attachment?(attachment)

      ensure_provider_file_size!(attachment)
      Attachment.new(@provider.upload_file(attachment, **provider_file_upload_options(attachment)))
    end

    def upload_large_attachment?(attachment)
      size = attachment.byte_size
      size && size > default_large_file_upload_threshold && provider_file_attachable?(attachment)
    end

    def default_large_file_upload_threshold
      Float::INFINITY
    end

    def provider_file_upload_limit
      nil
    end

    def provider_file_attachable?(_attachment)
      false
    end

    def provider_file_upload_options(_attachment)
      {}
    end

    def ensure_provider_file_size!(attachment)
      limit = provider_file_upload_limit
      return unless limit && attachment.byte_size.to_i > limit

      raise Error, "#{@provider.name} file uploads support files up to #{format_bytes(limit)}; " \
                   "#{attachment.filename} is #{format_bytes(attachment.byte_size)}"
    end

    def format_bytes(bytes)
      return 'unknown size' unless bytes

      "#{(bytes.to_f / (1024 * 1024)).round(1)} MB"
    end

    def validate_paint_inputs!(with:, mask:)
      return if with.nil? && mask.nil?

      raise UnsupportedAttachmentError, 'image reference'
    end

    def build_audio_file_part(file_path)
      require 'faraday/multipart'
      require 'marcel'
      require 'pathname'

      expanded_path = File.expand_path(file_path)
      mime_type = Marcel::MimeType.for(Pathname.new(expanded_path))

      Faraday::Multipart::FilePart.new(
        expanded_path,
        mime_type,
        File.basename(expanded_path)
      )
    end

    def sync_response(payload, additional_headers = {})
      response = @connection.post completion_url, payload do |req|
        req.headers = additional_headers.merge(req.headers) unless additional_headers.empty?
      end
      parse_completion_response response
    end

    def parse_completion_response(response)
      body = response.body
      if body.nil? || (body.respond_to?(:empty?) && body.empty?)
        raise Error.new('Provider returned an empty response body', response:)
      end

      parse_completion_body(body, raw: response)
    end
  end
end

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
  # transcription, token counting, and model listing) is served by three
  # kinds of seam method you override:
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
    abstract :render_count_tokens_payload, :count_tokens_url, :parse_count_tokens_response

    def initialize(provider, model = nil)
      @provider = provider
      @config = provider.config
      @connection = provider.connection
      @model = model
    end

    def complete(messages, tools:, temperature:, provider_options: {}, headers: {}, schema: nil, thinking: nil,
                 max_output_tokens: nil, citations: false, caching: nil, tool_prefs: nil, before_request: [],
                 usage_recorder: nil, server_tools: [], &)
      resolution = resolve_server_tools_for_request(server_tools)
      headers = resolution.headers.merge(headers) if resolution
      payload = render(
        messages, tools:, tool_prefs:, temperature:, max_output_tokens:, provider_options:, schema:, thinking:,
                  citations:, caching:, before_request:, server_tools:, stream: block_given?
      )

      track_usage(:chat, on_finish: usage_recorder) do
        if block_given?
          stream_response(payload, headers) do |chunk|
            @usage_tracker.observe(chunk)
            yield chunk
          end
        else
          sync_response payload, headers
        end
      end
    end

    def render(messages, tools:, temperature:, provider_options: {}, schema: nil, thinking: nil,
               max_output_tokens: nil, citations: false, caching: nil, tool_prefs: nil, before_request: [],
               stream: false, server_tools: [])
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
      payload = apply_server_tools(payload, server_tools)
      apply_before_request_hooks(payload, before_request)
    end

    # The alias table mapping portable server tool names to this protocol's
    # wire format. Protocols with server-tool support override this;
    # +nil+ means the protocol has no server-tool support at all.
    def server_tool_aliases
      nil
    end

    def count_tokens(messages, tools:, tool_prefs: nil, thinking: nil, schema: nil, citations: false, caching: nil)
      payload = render_count_tokens_payload(
        messages,
        tools: tools,
        tool_prefs: tool_prefs,
        model: model,
        schema: schema,
        thinking: thinking,
        citations: citations,
        caching: caching
      )
      parse_count_tokens_response post_count_tokens(payload)
    rescue NotImplementedError
      raise Error, "#{@provider.name} doesn't support token counting"
    end

    def list_models
      response = @connection.get models_url
      parse_list_models_response response, @provider.slug, @provider.capabilities
    end

    def embed(text, model:, dimensions:, task_type: nil, title: nil, provider_options: {})
      track_usage(:embedding) do
        payload = render_embedding_payload(text, model:, dimensions:, task_type:, title:, provider_options:)
        response = @connection.post(embedding_url(model:), payload, usage: @usage_tracker)
        parse_embedding_response(response, model:, text:)
      end
    end

    def moderate(input, model:, with: [], provider_options: {})
      track_usage(:moderation) do
        payload = render_moderation_payload(input, model:, with: Attachment.wrap(with), provider_options:)
        response = @connection.post moderation_url, payload, usage: @usage_tracker
        parse_moderation_response(response, model:)
      end
    end

    def paint(prompt, model:, size:, with: nil, mask: nil, provider_options: {})
      track_usage(:image) do
        validate_paint_inputs!(with:, mask:)
        payload = render_image_payload(prompt, model:, size:, with:, mask:, provider_options:)
        response = @connection.post images_url(with:, mask:), payload, usage: @usage_tracker
        parse_image_response(response, model:)
      end
    end

    def speak(input, model:, voice:, format:, provider_options: {})
      track_usage(:speech) do
        payload = render_speech_payload(input, model:, voice:, format:, provider_options:)
        response = @connection.post speech_url(model:), payload, usage: @usage_tracker
        parse_speech_response(response, model:, voice:, format:)
      end
    end

    def transcribe(audio_file, model:, language:, format: nil, speaker_names: nil,
                   speaker_references: nil, provider_options: {}, prompt: nil, temperature: nil)
      track_usage(:transcription) do
        file_part = build_audio_file_part(audio_file)
        payload = render_transcription_payload(file_part, model:, language:, format:, speaker_names:,
                                                          speaker_references:, provider_options:, prompt:,
                                                          temperature:)
        response = @connection.post transcription_url, payload, usage: @usage_tracker
        parse_transcription_response(response, model:)
      end
    end

    def maybe_normalize_temperature(temperature, model)
      drop_unsupported_temperature(temperature, model)
    end

    # Newer model generations reject sampling parameters outright; the
    # registry records that as temperature: false in model metadata.
    def drop_unsupported_temperature(temperature, model)
      return temperature if temperature.nil?
      return temperature unless model.metadata[:temperature] == false

      RubyLLM.logger.debug { "#{model.id} does not accept a temperature parameter, removing" }
      nil
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

    def resolve_server_tools_for_request(entries)
      return nil if entries.nil? || entries.empty?

      aliases = server_tool_aliases
      unless aliases
        raise UnsupportedServerToolError,
              "#{@provider.name} has no server-tool support through RubyLLM yet. " \
              'Request options in the provider vocabulary can be set with with_provider_options.'
      end

      ServerTools.resolve(entries, aliases: aliases, owner: @provider.name)
    end

    def apply_server_tools(payload, entries)
      resolution = resolve_server_tools_for_request(entries)
      return payload unless resolution

      payload = Utils.deep_merge(payload, resolution.payload) unless resolution.payload.empty?
      merge_server_tool_entries(payload, resolution.tools) if resolution.tools.any?
      payload
    end

    # Server tools join function tools in the payload's tools array. The
    # entry shape comes from the alias table or the caller's raw Hash.
    def merge_server_tool_entries(payload, entries)
      payload[:tools] = Array(payload[:tools]) + entries
    end

    def track_usage(operation, on_finish: nil)
      @usage_tracker = Usage::Tracker.new(
        operation:,
        provider: @provider,
        model: @model,
        config: @config,
        on_finish:
      )
      result = yield
      @usage_tracker.succeed(result)
      result
    rescue StandardError => e
      @usage_tracker.fail_pending(e)
      raise
    ensure
      @usage_tracker = nil
    end

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

    def post_count_tokens(payload)
      @connection.post count_tokens_url, payload
    end

    def sync_response(payload, additional_headers = {})
      response = @connection.post completion_url, payload, usage: @usage_tracker do |req|
        req.headers = additional_headers.merge(req.headers) unless additional_headers.empty?
      end
      parse_completion_response response
    end

    def parse_completion_response(response)
      body = response.body
      if body.nil? || (body.respond_to?(:empty?) && body.empty?)
        raise Error.new('Provider returned an empty response body', response:)
      end

      message = parse_completion_body(body, raw: response)
      raise Error.new('Provider returned no completion message', response:) unless message

      message
    end
  end
end

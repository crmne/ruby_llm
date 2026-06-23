# frozen_string_literal: true

module RubyLLM
  # Base class for wire protocols. A protocol knows how to talk to a family
  # of APIs: rendering payloads, parsing responses, streaming chunks, and the
  # endpoints involved. Providers know where to talk and who they are.
  class Protocol
    include Streaming

    attr_reader :provider, :config, :connection, :model

    def initialize(provider, model = nil)
      @provider = provider
      @config = provider.config
      @connection = provider.connection
      @model = model
    end

    # rubocop:disable Metrics/ParameterLists
    def complete(messages, tools:, temperature:, params: {}, headers: {}, schema: nil, thinking: nil,
                 citations: false, tool_prefs: nil, &)
      payload = render(
        messages,
        tools:, tool_prefs:, temperature:, params:, schema:, thinking:, citations:,
        stream: block_given?
      )

      if block_given?
        stream_response payload, headers, &
      else
        sync_response payload, headers
      end
    end

    def render(messages, tools:, temperature:, params: {}, schema: nil, thinking: nil,
               citations: false, tool_prefs: nil, stream: false)
      Utils.deep_merge(
        render_payload(
          messages,
          tools: tools,
          tool_prefs: tool_prefs,
          temperature: maybe_normalize_temperature(temperature, model),
          model: model,
          stream: stream,
          schema: schema,
          thinking: thinking,
          citations: citations
        ),
        params
      )
    end
    # rubocop:enable Metrics/ParameterLists

    def list_models
      response = @connection.get models_url
      parse_list_models_response response, @provider.slug, @provider.capabilities
    end

    def embed(text, model:, dimensions:)
      payload = render_embedding_payload(text, model:, dimensions:)
      response = @connection.post(embedding_url(model:), payload)
      parse_embedding_response(response, model:, text:)
    end

    def moderate(input, model:)
      payload = render_moderation_payload(input, model:)
      response = @connection.post moderation_url, payload
      parse_moderation_response(response, model:)
    end

    def paint(prompt, model:, size:, with: nil, mask: nil, params: {}) # rubocop:disable Metrics/ParameterLists
      validate_paint_inputs!(with:, mask:)
      payload = render_image_payload(prompt, model:, size:, with:, mask:, params:)
      response = @connection.post images_url(with:, mask:), payload
      parse_image_response(response, model:)
    end

    def speak(input, model:, voice:, format:, params: {}, **options) # rubocop:disable Metrics/ParameterLists
      payload = render_speech_payload(input, model:, voice:, format:, params:, **options)
      response = @connection.post speech_url(model:), payload
      parse_speech_response(response, model:, voice:, format:)
    end

    def transcribe(audio_file, model:, language:, **options)
      file_part = build_audio_file_part(audio_file)
      payload = render_transcription_payload(file_part, model:, language:, **options)
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
      return message unless message.content.is_a?(Content)

      attachments = message.content.attachments
      uploaded = attachments.map { |attachment| preprocess_attachment(attachment) }
      return message if uploaded == attachments

      message.dup.tap do |copy|
        copy.content = Content.new(message.content.text, uploaded)
      end
    end

    private

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
  end
end

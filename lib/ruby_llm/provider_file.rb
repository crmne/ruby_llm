# frozen_string_literal: true

module RubyLLM
  # Represents a provider-managed file upload or file info.
  class ProviderFile
    attr_reader :id, :filename, :byte_size, :created_at

    def initialize(id:, filename:, byte_size:, created_at:)
      @id = id
      @filename = filename
      @byte_size = byte_size
      @created_at = created_at
    end

    def self.upload(file, provider:, context: nil, **options)
      provider_instance = resolve_provider(provider:, context:)
      provider_instance.upload_file(file, **options)
    end

    def self.file_info(file_id, provider:, context: nil)
      provider_instance = resolve_provider(provider:, context:)
      provider_instance.file_info(file_id)
    end

    def self.download(file_id, provider:, context: nil, **options)
      provider_instance = resolve_provider(provider:, context:)
      provider_instance.download_file(file_id, **options)
    end

    def self.resolve_provider(provider:, context:)
      config = context&.config || RubyLLM.config
      provider_class = provider ? Provider.providers[provider.to_sym] : nil
      provider_class ||= raise(Error, "Unknown provider: #{provider.to_sym}")

      provider_class.new(config)
    end
  end
end

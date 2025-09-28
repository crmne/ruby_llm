# frozen_string_literal: true

module RubyLLM
  # Represents an image that may not be fully generated yet.
  class DeferredImage
    include Blobbable

    attr_reader :provider_instance, :url

    def initialize(url:, provider_instance:)
      @url = url
      @provider_instance = provider_instance
    end

    def to_blob
      provider_instance.fetch_image_blob(url)
    end
  end
end

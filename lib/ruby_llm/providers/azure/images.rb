# frozen_string_literal: true

module RubyLLM
  module Providers
    class Azure
      # Azure image endpoints use multipart uploads for edits.
      module Images
        def images_url(with: nil, mask: nil)
          @provider.azure_media_url(super)
        end

        def render_edit_payload(prompt, size:, provider_options:, **options)
          super(prompt, size:, provider_options: { size: size }.compact.merge(provider_options), **options)
        end

        def json_image_references?(_model)
          false
        end
      end
    end
  end
end

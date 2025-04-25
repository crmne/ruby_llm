module RubyLLM
  module Providers
    module Mistral
      # Media handling for Mistral models
      #
      # NOTE: There's currently an issue with Pixtral vision capabilities in the test suite.
      # The content array contains nil values when an image is attached, which causes the API to return errors.
      # This might be due to how images are being attached or formatted in the Content class.
      # The test in chat_content_spec.rb for 'pixtral-12b-latest can understand images' currently fails.
      # The debug output shows: content: [{type: "text", text: "..."}, nil] where the second element should be the image.
      # This likely requires fixes in the core library's Content class or how it interacts with provider-specific formatting.
      module Media
        module_function

        def supports_image?(model_id)
          # Check if the model supports vision according to the model capabilities
          capabilities.supports_vision?(model_id)
        end

        def supports_audio?(model_id)
          # Check if the model supports audio according to the model capabilities
          capabilities.supports_audio?(model_id)
        end
      end
    end
  end
end

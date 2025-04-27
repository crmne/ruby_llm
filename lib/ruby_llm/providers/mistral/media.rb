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

        # Moved from chat.rb
        def format_content(content)
          return content unless content.is_a?(Array)

          RubyLLM.logger.debug "Formatting multimodal content: #{content.inspect}"

          # Filter out nil values
          filtered_content = content.compact

          RubyLLM.logger.debug "Filtered content: #{filtered_content.inspect}"

          filtered_content.map do |item|
            if item.is_a?(Hash) && item[:type] == "image"
              format_image_content(item)
            else
              item # Pass through text or other types
            end
          end
        end

        # Format image according to Mistral API requirements
        # @param image [Hash] Image data hash from Content class
        # @return [Hash] Formatted image data for Mistral API
        def format_image_content(image)
          RubyLLM.logger.debug "Formatting image content: #{image.inspect}"
          
          if image[:source].is_a?(Hash)
            if image[:source][:url]
              # Direct URL from source hash
              {
                type: "image_url",
                image_url: image[:source][:url]
              }
            elsif image[:source][:type] == 'base64'
              # Base64 data from source hash
              data_uri = "data:#{image[:source][:media_type]};base64,#{image[:source][:data]}"
              {
                type: "image_url",
                image_url: data_uri
              }
            else
              RubyLLM.logger.warn "Invalid image source format: #{image[:source]}"
              nil
            end
          elsif image[:source].is_a?(String)
            # Direct URL string
            {
              type: "image_url",
              image_url: image[:source]
            }
          else
            RubyLLM.logger.warn "Invalid image format: #{image}"
            nil
          end
        end
      end
    end
  end
end

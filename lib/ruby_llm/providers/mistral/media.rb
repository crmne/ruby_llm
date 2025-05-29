module RubyLLM
  module Providers
    module Mistral
      # Media handling for Mistral models

      module Media
        module_function

        def format_content(content)
          return content unless content.is_a?(Content)

          parts = []
          parts << { type: "text", text: content.text } if content.text

          content.attachments.each do |attachment|
            case attachment.type
            when :image
              parts << format_image(attachment)
            when :pdf
              # Mistral doesn't currently support PDFs other than
              # through the OCR API
              raise UnsupportedAttachmentError, attachment.type
            when :audio
              # Mistral doesn't currently support audio
              raise UnsupportedAttachmentError, attachment.type
            when :text
              # Mistral doesn't support text files as attachments, so we'll append to the text
              if parts.first && parts.first[:type] == "text"
                parts.first[:text] += "\n\n" + Utils.format_text_file_for_llm(attachment)
              else
                parts << { type: "text", text: Utils.format_text_file_for_llm(attachment) }
              end
            else
              raise UnsupportedAttachmentError, attachment.type
            end
          end

          # Filter out nil values and return the formatted content array
          parts.compact
        end

        # Format image according to Mistral API requirements
        # @param image [Attachment] Image attachment
        # @return [Hash] Formatted image data for Mistral API
        def format_image(attachment)
          url = if attachment.respond_to?(:source) && attachment.source.to_s.match?(/^https?:\/\//)
            attachment.source.to_s
          else
            "data:#{attachment.mime_type};base64,#{attachment.encoded}"
          end
          {
            type: "image_url",
            image_url: url
          }
        end

        def supports_image?(model_id)
          # Check if the model supports vision according to the model capabilities
          capabilities.supports_vision?(model_id)
        end

        def supports_audio?(model_id)
          # Check if the model supports audio according to the model capabilities
          capabilities.supports_audio?(model_id)
        end

        def capabilities
          RubyLLM::Providers::Mistral::Capabilities
        end
      end
    end
  end
end

# frozen_string_literal: true

module RubyLLM
  module Providers
    module Gemini
      # Media handling methods for the Gemini API integration
      module Media
        module_function

        def format_content(content)
          return [format_text(content)] unless content.is_a?(Content)

          parts = []
          parts << format_text(content.text) if content.text

          content.attachments.each do |attachment|
            parts << case attachment
                     when Attachments::Text
                       format_text_file(attachment)
                     else
                       format_attachment(attachment)
                     end
          end

          parts
        end

        def format_attachment(attachment)
          {
            inline_data: {
              mime_type: attachment.mime_type,
              data: attachment.encoded
            }
          }
        end

        def format_text_file(text_file)
          {
            text: Utils.format_text_file_for_llm(text_file)
          }
        end

        def format_text(text)
          {
            text: text
          }
        end
      end
    end
  end
end

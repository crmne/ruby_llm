# frozen_string_literal: true

module RubyLLM
  module Providers
    module OpenAI
      # Handles formatting of media content (images, audio) for OpenAI APIs
      module Media
        module_function

        def format_content(content) # rubocop:disable Metrics/MethodLength
          return content unless content.is_a?(Array)

          content.map do |part|
            case part[:type]
            when 'image'
              format_image(part)
            when 'input_audio'
              format_audio(part)
            when 'pdf'
              format_pdf(part)
            else
              part
            end
          end
        end

        def format_image(part)
          {
            type: 'image_url',
            image_url: {
              url: format_data_url(part[:source]),
              detail: 'auto'
            }
          }
        end

        def format_audio(part)
          {
            type: 'input_audio',
            input_audio: part[:input_audio]
          }
        end

        def format_pdf(part)
          {
            type: 'file',
            file: {
              filename: File.basename(part[:source]),
              file_data: "data:application/pdf;base64,#{Base64.strict_encode64(part[:content])}"
            }
          }
        end

        def format_data_url(source)
          if source[:type] == 'base64'
            "data:#{source[:media_type]};base64,#{source[:data]}"
          else
            source[:url]
          end
        end
      end
    end
  end
end

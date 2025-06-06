# frozen_string_literal: true

module RubyLLM
  module Providers
    module OpenRouter
      # Handles formatting of media content (images, audio) for OpenRouter APIs
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

        # @see https://openrouter.ai/docs/features/images-and-pdfs#image-inputs
        def format_image(part)
          {
            type: 'image_url',
            image_url: {
              url: format_image_url(part[:source]),
              detail: 'auto'
            }
          }
        end

        def format_image_url(source)
          if source[:type] == 'base64'
            "data:#{source[:media_type]};base64,#{source[:data]}"
          else
            source[:url]
          end
        end

        def format_audio(part)
          {
            type: 'input_audio',
            input_audio: part[:input_audio]
          }
        end

        # @see https://openrouter.ai/docs/features/images-and-pdfs#pdf-support
        def format_pdf(part)
          {
            type: 'file',
            file: {
              filename: File.basename(part[:source]),
              file_data: format_file_data(part[:content] || part[:source])
            }
          }
        end

        def format_file_data(source)
          source = Faraday.get(source).body if source.start_with?('http')

          "data:application/pdf;base64,#{Base64.strict_encode64(source)}"
        end
      end
    end
  end
end

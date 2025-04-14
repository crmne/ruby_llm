# frozen_string_literal: true

module RubyLLM
  module Providers
    module Anthropic
      # Handles formatting of media content (images, PDFs, audio) for Anthropic
      module Media
        module_function

        def format_content(content, cache_control = nil) # rubocop:disable Metrics/MethodLength
          return content unless content.is_a?(Array)

          content.map do |part|
            case part[:type]
            when 'image'
              format_image(part)
            when 'pdf'
              format_pdf(part)
            when 'text'
              format_text_block(part[:text], cache_control)
            else
              part
            end
          end
        end

        def format_image(part)
          # Handle image formatting for Anthropic
          # This is just a placeholder - implement based on Anthropic's requirements
          part
        end

        def format_pdf(part) # rubocop:disable Metrics/MethodLength
          source = part[:source]

          if source.start_with?('http')
            # For URLs - add "type": "url" here
            {
              type: 'document',
              source: {
                type: 'url', # This line is missing in the current implementation
                url: source
              }
            }
          else
            # For local files
            data = Base64.strict_encode64(part[:content])

            {
              type: 'document',
              source: {
                type: 'base64',
                media_type: 'application/pdf',
                data: data
              }
            }
          end
        end

        def format_text_block(text, cache_control = nil)
          block = {
            type: 'text',
            text: text
          }
          
          block[:cache_control] = { type: 'ephemeral' } if cache_control
          block
        end
      end
    end
  end
end

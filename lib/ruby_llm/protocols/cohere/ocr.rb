# frozen_string_literal: true

module RubyLLM
  module Protocols
    class Cohere
      # Cohere Parse accepts one document image and returns Markdown or blocks.
      module OCR
        module_function

        def ocr_url
          'v2/parse'
        end

        def render_ocr_payload(file, model:, pages: nil, provider_options: {})
          attachment = file.is_a?(Attachment) ? file : Attachment.new(file, config: @config)
          raise UnsupportedAttachmentError, attachment.mime_type unless attachment.image?
          raise ArgumentError, 'Cohere Parse accepts one image; pages must be [0]' unless pages.nil? || pages == [0]

          reference = attachment.url? ? attachment.source.to_s : attachment.for_llm
          {
            model: model,
            document: { type: 'image_url', image_url: reference },
            output_format: 'markdown'
          }.merge(provider_options)
        end

        def parse_ocr_response(response, model:)
          data = response.body
          RubyLLM::OCR.new(
            pages: data.fetch('pages').map { |page| parse_ocr_page(page) },
            model: model,
            usage: data.dig('meta', 'billed_units'),
            raw: data
          )
        end

        def parse_ocr_page(page)
          content = page['markdown'] || parse_ocr_blocks(page.fetch('blocks'))
          RubyLLM::OCR::Page.new(
            index: page['index'], markdown: content['content'],
            images: content['images'], tables: content['tables'], raw: page
          )
        end

        def parse_ocr_blocks(blocks)
          {
            'content' => blocks.filter_map { |block| parse_ocr_block_text(block) }.join("\n\n"),
            'images' => blocks.filter_map { |block| block['image'] },
            'tables' => blocks.filter_map { |block| block['table'] }
          }
        end

        def parse_ocr_block_text(block)
          case block['type']
          when 'text' then block.dig('text', 'content')
          when 'table' then block.dig('table', 'html')
          when 'image' then "![#{block.dig('image', 'description')}](#{block.dig('image', 'id')})"
          end
        end
      end
    end
  end
end

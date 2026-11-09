# frozen_string_literal: true

module RubyLLM
  module Providers
    class ZAI
      # Layout parsing with GLM-OCR. Files go up as URLs or data URIs, and
      # each page comes back as a list of layout elements.
      module OCR
        def ocr_url
          'layout_parsing'
        end

        def render_ocr_payload(file, model:, pages: nil, provider_options: {})
          attachment = file.is_a?(Attachment) ? file : Attachment.new(file, config: @config)

          payload = { model:, file: attachment.url_or_data_uri }.merge(ocr_page_range(pages))
                                                                .merge(provider_options.transform_keys(&:to_sym))
          @ocr_first_page = payload[:start_page_id].to_i.pred.clamp(0..)
          payload
        end

        def parse_ocr_response(response, model:)
          data = response.body
          RubyLLM::OCR.new(pages: parse_ocr_pages(data), model:, usage: data['usage'], raw: data)
        end

        private

        def ocr_page_range(pages)
          return {} if pages.nil?

          first, last = pages.minmax
          continuous = first && pages.sort.each_cons(2).all? { |page, following| following == page + 1 }
          raise ArgumentError, 'Z.ai reads one continuous page range' unless continuous

          { start_page_id: first + 1, end_page_id: last + 1 }
        end

        def parse_ocr_pages(data)
          details = data['layout_details']
          if details.nil? || details.empty?
            return [RubyLLM::OCR::Page.new(index: @ocr_first_page.to_i, markdown: data['md_results'], raw: data)]
          end

          details.each_with_index.map { |elements, position| parse_ocr_page(elements, position) }
        end

        def ocr_element_markdown(element)
          content = element['content']
          content && element['label'] == 'image' ? "![](#{content})" : content
        end

        def parse_ocr_page(elements, position)
          RubyLLM::OCR::Page.new(
            index: @ocr_first_page.to_i + position,
            markdown: elements.filter_map { |element| ocr_element_markdown(element) }.join("\n\n"),
            images: elements.select { |element| element['label'] == 'image' },
            tables: elements.select { |element| element['label'] == 'table' },
            raw: { 'layout_details' => elements }
          )
        end
      end
    end
  end
end

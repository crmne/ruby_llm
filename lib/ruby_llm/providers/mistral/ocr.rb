# frozen_string_literal: true

module RubyLLM
  module Providers
    class Mistral
      # Document OCR methods for the Mistral API. Remote files are passed as
      # URLs; local files are inlined as base64 data URIs. Images go through
      # the image_url document variant, everything else through document_url.
      module OCR
        module_function

        def ocr_url
          'ocr'
        end

        def render_ocr_payload(file, model:, options: {})
          attachment = file.is_a?(Attachment) ? file : Attachment.new(file)

          {
            model: model,
            document: ocr_document_part(attachment)
          }.merge(options)
        end

        def ocr_document_part(attachment)
          reference = attachment.url? ? attachment.source.to_s : attachment.for_llm

          if attachment.image?
            { type: 'image_url', image_url: reference }
          else
            { type: 'document_url', document_url: reference }
          end
        end

        def parse_ocr_response(response, model:)
          data = response.body

          RubyLLM::OCR.new(
            pages: data['pages'],
            model: data['model'] || model,
            usage: data['usage_info'],
            raw: data
          )
        end
      end
    end
  end
end
